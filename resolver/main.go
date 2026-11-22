// Pitcrew resolver sidecar: runs one ecosystem's lockfile update inside a checkout the
// app placed in the shared /work volume. Compiled to a static binary, so the same file
// runs on any Linux base image (ruby:2.4, ruby:3.4-slim, node:22-slim, ...).
//
//	GET  /health               -> {"ok":true,"runtimes":{"ruby":"3.4.9"},"ecosystems":["bundler"]}
//	POST /resolve/<ecosystem>  {"dir":"a1b2c3","packages":["rack"],"level":"patch","env":{...}}
//	                           -> {"ok":bool,"exit":int,"stdout":"...","stderr":"..."}
//
// The repo's manifest (Gemfile, package.json) is untrusted code, which is why this runs
// here and not in the app: this container holds no database credentials and no GitHub
// App key. Ecosystem-specific rules live in ecosystems.go.
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"
)

const (
	outputLimit = 20_000          // bytes of stdout/stderr returned
	maxBody     = 1_000_000       // bytes of request body accepted
	maxPackages = 500             // packages per request
	timeout     = 5 * time.Minute // a big Rails app resolves in well under this
)

// One path segment under the work root: no "../", no nesting.
var dirPattern = regexp.MustCompile(`^[A-Za-z0-9_-]{1,100}$`)

// Request is the JSON body of POST /resolve/<ecosystem>.
type Request struct {
	Dir      string            `json:"dir"`
	Packages []string          `json:"packages"`
	Level    string            `json:"level"`
	Env      map[string]string `json:"env"`
}

// Runner runs a command and reports its output and exit status. Swapped out in tests.
type Runner func(ctx context.Context, dir string, env []string, argv []string) (stdout, stderr string, exit int)

// Server holds what one resolver serves: the ecosystems available in this image and
// the runtime versions it reports.
type Server struct {
	WorkRoot   string
	Ecosystems map[string]Ecosystem
	Runtimes   map[string]string
	Run        Runner
}

func main() {
	server := &Server{
		WorkRoot:   envOr("RESOLVER_WORK_ROOT", "/work"),
		Ecosystems: map[string]Ecosystem{},
		Runtimes:   map[string]string{},
		Run:        runCommand,
	}
	// Only serve ecosystems whose tool is actually in this image.
	for name, eco := range ecosystems {
		if _, err := exec.LookPath(eco.Tool); err != nil {
			continue
		}
		server.Ecosystems[name] = eco
		if out, err := exec.Command(eco.VersionCmd[0], eco.VersionCmd[1:]...).Output(); err == nil {
			server.Runtimes[eco.Runtime] = strings.TrimSpace(string(out))
		}
	}

	port := envOr("PORT", "9292")
	log.Printf("[resolver] runtimes %v, ecosystems %v, listening on %s", server.Runtimes, server.names(), port)
	log.Fatal(http.ListenAndServe(":"+port, server.Routes()))
}

// Routes maps the two endpoints to their handlers.
func (s *Server) Routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		reply(w, http.StatusOK, map[string]any{"ok": true, "runtimes": s.Runtimes, "ecosystems": s.names()})
	})
	mux.HandleFunc("POST /resolve/{ecosystem}", func(w http.ResponseWriter, r *http.Request) {
		eco, ok := s.Ecosystems[r.PathValue("ecosystem")]
		if !ok {
			reply(w, http.StatusNotFound, map[string]any{"ok": false, "error": "ecosystem not available here"})
			return
		}
		s.resolve(eco, w, r)
	})
	return mux
}

func (s *Server) resolve(eco Ecosystem, w http.ResponseWriter, r *http.Request) {
	var req Request
	if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBody)).Decode(&req); err != nil {
		reply(w, http.StatusBadRequest, map[string]any{"ok": false, "error": "invalid JSON"})
		return
	}
	if problem := s.validate(eco, req); problem != "" {
		reply(w, http.StatusUnprocessableEntity, map[string]any{"ok": false, "error": problem})
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), timeout) // kill it if it runs too long
	defer cancel()                                           // runs when this function returns

	path := filepath.Join(s.WorkRoot, req.Dir)
	env := eco.Env(path)
	for key, value := range req.Env {
		env = append(env, key+"="+value)
	}
	stdout, stderr, exit := s.Run(ctx, path, env, eco.Command(req))
	reply(w, http.StatusOK, map[string]any{
		"ok": exit == 0, "exit": exit, "stdout": tail(stdout), "stderr": tail(stderr),
	})
}

// validate returns what's wrong with the request, or "" if it's fine. Nothing runs
// unless every check passes.
func (s *Server) validate(eco Ecosystem, req Request) string {
	if !dirPattern.MatchString(req.Dir) {
		return "dir must be a single path segment"
	}
	if len(req.Packages) == 0 || len(req.Packages) > maxPackages {
		return "packages must be a non-empty list"
	}
	for _, name := range req.Packages {
		if !eco.PackageName.MatchString(name) {
			return "invalid package name: " + name
		}
	}
	if !slices.Contains(eco.Levels, req.Level) {
		return "level must be one of " + strings.Join(eco.Levels, ", ")
	}
	for key := range req.Env {
		if !eco.EnvKey.MatchString(key) {
			return "env may only set credential keys"
		}
	}
	if info, err := os.Stat(filepath.Join(s.WorkRoot, req.Dir, eco.Manifest)); err != nil || info.IsDir() {
		return "no " + eco.Manifest + " in " + req.Dir
	}
	return ""
}

func (s *Server) names() []string {
	names := make([]string, 0, len(s.Ecosystems))
	for name := range s.Ecosystems {
		names = append(names, name)
	}
	slices.Sort(names)
	return names
}

// runCommand runs argv directly (no shell, so arguments can't inject anything) in dir,
// with this process's env plus the extra entries.
func runCommand(ctx context.Context, dir string, env []string, argv []string) (string, string, int) {
	cmd := exec.CommandContext(ctx, argv[0], argv[1:]...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(), env...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &stdout, &stderr

	exit := 1
	if err := cmd.Run(); err == nil {
		exit = 0
	} else if cmd.ProcessState != nil { // nil if the command never started
		exit = cmd.ProcessState.ExitCode()
	}
	return stdout.String(), stderr.String(), exit
}

func reply(w http.ResponseWriter, status int, body map[string]any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(body)
}

// tail keeps the end of long output, where the error usually is.
func tail(s string) string {
	if len(s) > outputLimit {
		return s[len(s)-outputLimit:]
	}
	return s
}

func envOr(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
