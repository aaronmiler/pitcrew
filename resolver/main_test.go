package main

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

// call is one command the fake runner was asked to run.
type call struct {
	dir  string
	env  []string
	argv []string
}

// newTestServer serves bundler from a temp work root holding job1/Gemfile, and records
// commands instead of running them.
func newTestServer(t *testing.T, stdout, stderr string, exit int) (*httptest.Server, string, *[]call) {
	t.Helper()
	work := t.TempDir()
	if err := os.MkdirAll(filepath.Join(work, "job1"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(work, "job1", "Gemfile"), []byte("source 'https://rubygems.org'\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	calls := &[]call{}
	server := &Server{
		WorkRoot:   work,
		Ecosystems: map[string]Ecosystem{"bundler": ecosystems["bundler"]},
		Runtimes:   map[string]string{"ruby": "3.4.9"},
		Run: func(_ context.Context, dir string, env []string, argv []string) (string, string, int) {
			*calls = append(*calls, call{dir, env, argv})
			return stdout, stderr, exit
		},
	}
	ts := httptest.NewServer(server.Routes())
	t.Cleanup(ts.Close)
	return ts, work, calls
}

func valid() map[string]any {
	return map[string]any{"dir": "job1", "packages": []string{"rack", "rails"}, "level": "patch", "env": map[string]string{}}
}

func post(t *testing.T, server *httptest.Server, path string, body any) (int, map[string]any) {
	t.Helper()
	var payload string
	if s, ok := body.(string); ok {
		payload = s
	} else {
		encoded, _ := json.Marshal(body)
		payload = string(encoded)
	}
	response, err := http.Post(server.URL+path, "application/json", strings.NewReader(payload))
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	var decoded map[string]any
	json.NewDecoder(response.Body).Decode(&decoded)
	return response.StatusCode, decoded
}

func TestResolveRunsConservativeBundleLockInTheCheckout(t *testing.T) {
	server, work, calls := newTestServer(t, "resolved", "", 0)

	status, body := post(t, server, "/resolve/bundler", valid())

	if status != 200 || body["ok"] != true || body["stdout"] != "resolved" || body["exit"] != 0.0 {
		t.Fatalf("got %d %v", status, body)
	}
	got := (*calls)[0]
	want := []string{"bundle", "lock", "--update", "rack", "rails", "--conservative", "--patch"}
	if !slices.Equal(got.argv, want) {
		t.Errorf("argv = %v, want %v", got.argv, want)
	}
	if got.dir != filepath.Join(work, "job1") {
		t.Errorf("dir = %s", got.dir)
	}
	if !slices.Contains(got.env, "BUNDLE_GEMFILE="+filepath.Join(work, "job1")+"/Gemfile") {
		t.Errorf("env = %v, want BUNDLE_GEMFILE", got.env)
	}
}

func TestResolvePassesNoLevelFlagForLatest(t *testing.T) {
	server, _, calls := newTestServer(t, "", "", 0)
	request := valid()
	request["level"] = "latest"

	post(t, server, "/resolve/bundler", request)

	want := []string{"bundle", "lock", "--update", "rack", "rails", "--conservative"}
	if !slices.Equal((*calls)[0].argv, want) {
		t.Errorf("argv = %v, want %v", (*calls)[0].argv, want)
	}
}

func TestResolvePassesBundlerCredentialsThrough(t *testing.T) {
	server, _, calls := newTestServer(t, "", "", 0)
	request := valid()
	request["env"] = map[string]string{"BUNDLE_RUBYGEMS__PKG__GITHUB__COM": "token"}

	post(t, server, "/resolve/bundler", request)

	if !slices.Contains((*calls)[0].env, "BUNDLE_RUBYGEMS__PKG__GITHUB__COM=token") {
		t.Errorf("env = %v", (*calls)[0].env)
	}
}

func TestResolveReportsAFailedResolve(t *testing.T) {
	server, _, _ := newTestServer(t, "", "Could not find compatible versions", 6)

	status, body := post(t, server, "/resolve/bundler", valid())

	if status != 200 || body["ok"] != false || body["exit"] != 6.0 || body["stderr"] != "Could not find compatible versions" {
		t.Fatalf("got %d %v", status, body)
	}
}

func TestResolveRejectsBadRequestsWithoutRunningAnything(t *testing.T) {
	cases := map[string]map[string]any{
		"path traversal in dir":            {"dir": "../etc"},
		"a nested dir":                     {"dir": "job1/sub"},
		"a missing Gemfile":                {"dir": "nope"},
		"no packages":                      {"packages": []string{}},
		"a package name with shell syntax": {"packages": []string{"rack; rm -rf /"}},
		"a flag smuggled in as a package":  {"packages": []string{"--full-index"}},
		"an unknown level":                 {"level": "major"},
		"a non-Bundler env var":            {"env": map[string]string{"RUBYOPT": "-r/tmp/evil"}},
	}
	for name, override := range cases {
		t.Run(name, func(t *testing.T) {
			server, _, calls := newTestServer(t, "", "", 0)
			request := valid()
			for key, value := range override {
				request[key] = value
			}

			status, body := post(t, server, "/resolve/bundler", request)

			if status != 422 || body["ok"] != false || len(*calls) != 0 {
				t.Fatalf("got %d %v, %d calls", status, body, len(*calls))
			}
		})
	}
}

func TestResolveRejectsInvalidJSON(t *testing.T) {
	server, _, calls := newTestServer(t, "", "", 0)

	status, _ := post(t, server, "/resolve/bundler", "{x}")

	if status != 400 || len(*calls) != 0 {
		t.Fatalf("got %d, %d calls", status, len(*calls))
	}
}

func TestResolveRefusesAnEcosystemThisImageDoesntHave(t *testing.T) {
	server, _, calls := newTestServer(t, "", "", 0)

	status, _ := post(t, server, "/resolve/yarn", valid())

	if status != 404 || len(*calls) != 0 {
		t.Fatalf("got %d, %d calls", status, len(*calls))
	}
}

func TestHealthReportsRuntimesAndEcosystems(t *testing.T) {
	server, _, _ := newTestServer(t, "", "", 0)

	response, err := http.Get(server.URL + "/health")
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	var body struct {
		OK         bool              `json:"ok"`
		Runtimes   map[string]string `json:"runtimes"`
		Ecosystems []string          `json:"ecosystems"`
	}
	json.NewDecoder(response.Body).Decode(&body)

	if !body.OK || body.Runtimes["ruby"] != "3.4.9" || !slices.Equal(body.Ecosystems, []string{"bundler"}) {
		t.Fatalf("got %+v", body)
	}
}

func TestUnknownPathsAre404(t *testing.T) {
	server, _, _ := newTestServer(t, "", "", 0)

	response, err := http.Get(server.URL + "/nope")
	if err != nil {
		t.Fatal(err)
	}
	response.Body.Close()
	if response.StatusCode != 404 {
		t.Fatalf("got %d", response.StatusCode)
	}
}
