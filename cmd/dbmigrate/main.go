// Command dbmigrate applies SQL files under migrations/main using golang-migrate.
// SQLite uses the pure-Go driver (no CGO), suitable for Windows and CI.
// Migration sources use iofs (not file://) so Windows paths work.
//
// Usage:
//
//	go run ./cmd/dbmigrate -path migrations/main -database sqlite://.tmp/demo.db up
//	go run ./cmd/dbmigrate -path migrations/main -database sqlite://.tmp/demo.db version
//	go run ./cmd/dbmigrate -path migrations/main -database sqlite://.tmp/demo.db down 1
package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/sqlite"
	"github.com/golang-migrate/migrate/v4/source/iofs"
)

func main() {
	pathFlag := flag.String("path", "migrations/main", "path to migration files")
	dbFlag := flag.String("database", "", "database URL (sqlite://file.db | postgres://... | mysql://...)")
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fatal(errors.New("usage: dbmigrate -path DIR -database URL up|down [N]|version|force VERSION"))
	}
	cmd := strings.ToLower(args[0])

	dbURL := strings.TrimSpace(*dbFlag)
	if dbURL == "" {
		dbURL = strings.TrimSpace(os.Getenv("MIGRATE_DATABASE_URL"))
	}
	if dbURL == "" {
		fatal(errors.New("-database or MIGRATE_DATABASE_URL is required"))
	}
	dbURL = normalizeDatabaseURL(dbURL)

	absPath, err := filepath.Abs(*pathFlag)
	if err != nil {
		fatal(err)
	}
	info, err := os.Stat(absPath)
	if err != nil {
		fatal(fmt.Errorf("migrations path: %w", err))
	}
	if !info.IsDir() {
		fatal(fmt.Errorf("migrations path is not a directory: %s", absPath))
	}

	sourceDriver, err := iofs.New(os.DirFS(absPath), ".")
	if err != nil {
		fatal(err)
	}

	m, err := migrate.NewWithSourceInstance("iofs", sourceDriver, dbURL)
	if err != nil {
		fatal(err)
	}
	defer m.Close()

	switch cmd {
	case "up":
		if len(args) >= 2 {
			n, err := strconv.Atoi(args[1])
			if err != nil {
				fatal(err)
			}
			err = m.Steps(n)
			if err != nil && !errors.Is(err, migrate.ErrNoChange) {
				fatal(err)
			}
		} else {
			err = m.Up()
			if err != nil && !errors.Is(err, migrate.ErrNoChange) {
				fatal(err)
			}
		}
		printVersion(m)
	case "down":
		steps := 1
		if len(args) >= 2 {
			steps, err = strconv.Atoi(args[1])
			if err != nil {
				fatal(err)
			}
		}
		err = m.Steps(-steps)
		if err != nil && !errors.Is(err, migrate.ErrNoChange) {
			fatal(err)
		}
		printVersion(m)
	case "version":
		printVersion(m)
	case "force":
		if len(args) < 2 {
			fatal(errors.New("force requires VERSION"))
		}
		v, err := strconv.Atoi(args[1])
		if err != nil {
			fatal(err)
		}
		if err := m.Force(v); err != nil {
			fatal(err)
		}
		printVersion(m)
	default:
		fatal(fmt.Errorf("unknown command %q", cmd))
	}
}

func printVersion(m *migrate.Migrate) {
	v, dirty, err := m.Version()
	if errors.Is(err, migrate.ErrNilVersion) {
		fmt.Println("0")
		return
	}
	if err != nil {
		fatal(err)
	}
	if dirty {
		fmt.Printf("%d (dirty)\n", v)
		return
	}
	fmt.Printf("%d\n", v)
}

func normalizeDatabaseURL(raw string) string {
	if strings.HasPrefix(raw, "sqlite3://") {
		rest := strings.TrimPrefix(raw, "sqlite3://")
		return "sqlite://" + normalizeSQLitePath(rest)
	}
	if strings.HasPrefix(raw, "sqlite://") {
		rest := strings.TrimPrefix(raw, "sqlite://")
		return "sqlite://" + normalizeSQLitePath(rest)
	}
	if !strings.Contains(raw, "://") {
		abs, err := filepath.Abs(raw)
		if err != nil {
			return "sqlite://" + filepath.ToSlash(raw)
		}
		return "sqlite://" + filepath.ToSlash(abs)
	}
	return raw
}

func normalizeSQLitePath(path string) string {
	path = strings.TrimSpace(path)
	// Strip leading slashes before Windows drive letter: ///C:/x → C:/x
	for strings.HasPrefix(path, "/") {
		if len(path) >= 3 && path[2] == ':' {
			path = path[1:]
			break
		}
		if len(path) >= 2 && path[1] != '/' {
			// unix absolute /tmp/x
			break
		}
		path = strings.TrimPrefix(path, "/")
	}
	if path == "" {
		return path
	}
	// Keep relative paths relative (for CI cwd).
	if !filepath.IsAbs(path) && !(len(path) >= 2 && path[1] == ':') {
		return filepath.ToSlash(path)
	}
	abs, err := filepath.Abs(path)
	if err != nil {
		return filepath.ToSlash(path)
	}
	return filepath.ToSlash(abs)
}

func fatal(err error) {
	fmt.Fprintf(os.Stderr, "dbmigrate: %v\n", err)
	os.Exit(1)
}
