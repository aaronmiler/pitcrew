package main

import "regexp"

// Ecosystem is everything specific to one package manager: what must be installed, what
// input is allowed, and the exact command. Adding one (npm, yarn) means adding an entry
// to the map below; the server itself doesn't change.
type Ecosystem struct {
	Tool        string                     // must exist in the image, or the route is off
	Manifest    string                     // the checkout must contain this file
	Runtime     string                     // reported by /health, e.g. "ruby"
	VersionCmd  []string                   // prints the runtime's version
	PackageName *regexp.Regexp             // allowed package names
	EnvKey      *regexp.Regexp             // allowed credential env keys
	Levels      []string                   // allowed values for "level"
	Command     func(req Request) []string // the command to run, as argv (no shell)
	Env         func(path string) []string // extra env for the command, given the checkout path
}

var ecosystems = map[string]Ecosystem{
	"bundler": {
		Tool:       "bundle",
		Manifest:   "Gemfile",
		Runtime:    "ruby",
		VersionCmd: []string{"ruby", "-e", "print RUBY_VERSION"},
		// Must start with a letter or digit, so a flag like --full-index can't pass as a gem.
		PackageName: regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9._-]{0,100}$`),
		// Bundler credentials only: nothing like RUBYOPT, which would load arbitrary code.
		EnvKey: regexp.MustCompile(`^BUNDLE_[A-Z0-9_]+$`),
		Levels: []string{"patch", "minor", "latest"},
		Command: func(req Request) []string {
			cmd := append([]string{"bundle", "lock", "--update"}, req.Packages...)
			cmd = append(cmd, "--conservative")
			if req.Level != "latest" { // "latest" = no flag: the newest the Gemfile allows
				cmd = append(cmd, "--"+req.Level)
			}
			return cmd
		},
		Env: func(path string) []string {
			return []string{"BUNDLE_GEMFILE=" + path + "/Gemfile"}
		},
	},
}
