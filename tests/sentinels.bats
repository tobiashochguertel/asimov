#!/usr/bin/env bats
#
# Sentinel-pattern tests: one per unique directory/sentinel pair in asimov.

load test_helper

# --- Swift ---

@test "Swift: excludes .build when Package.swift is present" {
  create_project "Code/My-Project" "Package.swift" ".build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Gradle ---

@test "Gradle: excludes .gradle when build.gradle is present" {
  create_project "Code/My-Project" "build.gradle" ".gradle"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.gradle"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Gradle Kotlin: excludes .gradle when build.gradle.kts is present" {
  create_project "Code/My-Project" "build.gradle.kts" ".gradle"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.gradle"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Gradle: excludes build when build.gradle is present" {
  create_project "Code/My-Project" "build.gradle" "build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Gradle Kotlin: excludes build when build.gradle.kts is present" {
  create_project "Code/My-Project" "build.gradle.kts" "build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Dart / Flutter ---

@test "Dart: excludes .dart_tool when pubspec.yaml is present" {
  create_project "Code/My-Project" "pubspec.yaml" ".dart_tool"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.dart_tool"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Dart: excludes .packages when pubspec.yaml is present" {
  create_project "Code/My-Project" "pubspec.yaml" ".packages"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.packages"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Flutter: excludes build when pubspec.yaml is present" {
  create_project "Code/My-Project" "pubspec.yaml" "build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Haskell ---

@test "Stack: excludes .stack-work when stack.yaml is present" {
  create_project "Code/My-Project" "stack.yaml" ".stack-work"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.stack-work"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Python ---

@test "Tox: excludes .tox when tox.ini is present" {
  create_project "Code/My-Project" "tox.ini" ".tox"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.tox"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Nox: excludes .nox when noxfile.py is present" {
  create_project "Code/My-Project" "noxfile.py" ".nox"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.nox"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Python: excludes .venv when requirements.txt is present" {
  create_project "Code/My-Project" "requirements.txt" ".venv"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.venv"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Python: excludes .venv when pyproject.toml is present" {
  create_project "Code/My-Project" "pyproject.toml" ".venv"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.venv"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Python: excludes venv when requirements.txt is present" {
  create_project "Code/My-Project" "requirements.txt" "venv"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/venv"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Python: excludes venv when pyproject.toml is present" {
  create_project "Code/My-Project" "pyproject.toml" "venv"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/venv"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "PDM: excludes __pypackages__ when pyproject.toml is present" {
  create_project "Code/My-Project" "pyproject.toml" "__pypackages__"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/__pypackages__"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Python: excludes build when setup.py is present" {
  create_project "Code/My-Project" "setup.py" "build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Python: excludes dist when setup.py is present" {
  create_project "Code/My-Project" "setup.py" "dist"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/dist"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Vagrant ---

@test "Vagrant: excludes .vagrant when Vagrantfile is present" {
  create_project "Code/My-Project" "Vagrantfile" ".vagrant"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.vagrant"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- iOS / macOS ---

@test "Carthage: excludes Carthage when Cartfile is present" {
  create_project "Code/My-Project" "Cartfile" "Carthage"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/Carthage"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "CocoaPods: excludes Pods when Podfile is present" {
  create_project "Code/My-Project" "Podfile" "Pods"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/Pods"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Xcode: excludes DerivedData when *.xcodeproj is present" {
  mkdir -p "${HOME}/Code/My-Project/DerivedData"
  mkdir -p "${HOME}/Code/My-Project/MyApp.xcodeproj"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/DerivedData"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- JavaScript ---

@test "Bower: excludes bower_components when bower.json is present" {
  create_project "Code/My-Project" "bower.json" "bower_components"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/bower_components"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Node: excludes node_modules when package.json is present" {
  create_project "Code/My-Project" "package.json" "node_modules"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/node_modules"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Parcel: excludes .parcel-cache when package.json is present" {
  create_project "Code/My-Project" "package.json" ".parcel-cache"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.parcel-cache"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Next.js: excludes .next when package.json is present" {
  create_project "Code/My-Project" "package.json" ".next"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.next"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Nuxt: excludes .nuxt when package.json is present" {
  create_project "Code/My-Project" "package.json" ".nuxt"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.nuxt"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Angular: excludes .angular when angular.json is present" {
  create_project "Code/My-Project" "angular.json" ".angular"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.angular"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "SvelteKit: excludes .svelte-kit when svelte.config.js is present" {
  create_project "Code/My-Project" "svelte.config.js" ".svelte-kit"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.svelte-kit"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Turborepo: excludes .turbo when turbo.json is present" {
  create_project "Code/My-Project" "turbo.json" ".turbo"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.turbo"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Yarn Berry: excludes .yarn when .yarnrc.yml is present" {
  create_project "Code/My-Project" ".yarnrc.yml" ".yarn"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.yarn"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- moonrepo ---

@test "moonrepo: excludes cache when workspace.yml is present" {
  create_project "Code/My-Project/.moon" "workspace.yml" "cache"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.moon/cache"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "moonrepo: does not exclude cache without a workspace.yml sibling" {
  mkdir -p "${HOME}/Code/My-Project/cache"
  run_asimov
  refute_excluded "${HOME}/Code/My-Project/cache"
  [[ "$(count_exclusions)" -eq 0 ]]
}

# --- Rust ---

@test "Cargo: excludes target when Cargo.toml is present" {
  create_project "Code/My-Project" "Cargo.toml" "target"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/target"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Java / Scala ---

@test "Maven: excludes target when pom.xml is present" {
  create_project "Code/My-Project" "pom.xml" "target"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/target"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Sbt: excludes target when build.sbt is present" {
  create_project "Code/My-Project" "build.sbt" "target"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/target"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Sbt: excludes target when plugins.sbt is present" {
  create_project "Code/My-Project" "plugins.sbt" "target"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/target"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Clojure ---

@test "Leiningen: excludes target when project.clj is present" {
  create_project "Code/My-Project" "project.clj" "target"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/target"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Clojure CLI: excludes target when deps.edn is present" {
  create_project "Code/My-Project" "deps.edn" "target"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/target"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Clojure CLI: excludes .cpcache when deps.edn is present" {
  create_project "Code/My-Project" "deps.edn" ".cpcache"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.cpcache"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Shadow-CLJS: excludes .shadow-cljs when shadow-cljs.edn is present" {
  create_project "Code/My-Project" "shadow-cljs.edn" ".shadow-cljs"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.shadow-cljs"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- .NET ---

@test ".NET C#: excludes bin when *.csproj is present" {
  mkdir -p "${HOME}/Code/My-Project/bin"
  echo "sentinel" > "${HOME}/Code/My-Project/MyApp.csproj"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/bin"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test ".NET C#: excludes obj when *.csproj is present" {
  mkdir -p "${HOME}/Code/My-Project/obj"
  echo "sentinel" > "${HOME}/Code/My-Project/MyApp.csproj"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/obj"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test ".NET F#: excludes bin when *.fsproj is present" {
  mkdir -p "${HOME}/Code/My-Project/bin"
  echo "sentinel" > "${HOME}/Code/My-Project/MyApp.fsproj"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/bin"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test ".NET F#: excludes obj when *.fsproj is present" {
  mkdir -p "${HOME}/Code/My-Project/obj"
  echo "sentinel" > "${HOME}/Code/My-Project/MyApp.fsproj"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/obj"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- PHP ---

@test "Composer: excludes vendor when composer.json is present" {
  create_project "Code/My-Project" "composer.json" "vendor"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/vendor"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Ruby ---

@test "Bundler: excludes vendor when Gemfile is present" {
  create_project "Code/My-Project" "Gemfile" "vendor"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/vendor"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Go ---

@test "Go: excludes vendor when go.mod is present" {
  create_project "Code/My-Project" "go.mod" "vendor"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/vendor"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Elixir ---

@test "Elixir: excludes deps when mix.exs is present" {
  create_project "Code/My-Project" "mix.exs" "deps"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/deps"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Elixir: excludes .build when mix.exs is present" {
  create_project "Code/My-Project" "mix.exs" ".build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Elixir: excludes _build when mix.exs is present" {
  create_project "Code/My-Project" "mix.exs" "_build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/_build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Terraform ---

@test "Terraform: excludes .terraform.d when .terraformrc is present" {
  create_project "Code/My-Project" ".terraformrc" ".terraform.d"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.terraform.d"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Terragrunt: excludes .terragrunt-cache when terragrunt.hcl is present" {
  create_project "Code/My-Project" "terragrunt.hcl" ".terragrunt-cache"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.terragrunt-cache"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Terraform: excludes .terraform when .terraform.lock.hcl is present" {
  create_project "Code/My-Project" ".terraform.lock.hcl" ".terraform"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.terraform"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- direnv ---

@test "direnv: excludes .direnv when .envrc is present" {
  create_project "Code/My-Project" ".envrc" ".direnv"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.direnv"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- AWS ---

@test "AWS CDK: excludes cdk.out when cdk.json is present" {
  create_project "Code/My-Project" "cdk.json" "cdk.out"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/cdk.out"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- OCaml ---

@test "Dune: excludes _build when dune-project is present" {
  create_project "Code/My-Project" "dune-project" "_build"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/_build"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Zig ---

@test "Zig: excludes .zig-cache when build.zig is present" {
  create_project "Code/My-Project" "build.zig" ".zig-cache"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.zig-cache"
  [[ "$(count_exclusions)" -eq 1 ]]
}

@test "Zig: excludes zig-out when build.zig is present" {
  create_project "Code/My-Project" "build.zig" "zig-out"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/zig-out"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Elm ---

@test "Elm: excludes elm-stuff when elm.json is present" {
  create_project "Code/My-Project" "elm.json" "elm-stuff"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/elm-stuff"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- Godot ---

@test "Godot: excludes .godot when project.godot is present" {
  create_project "Code/My-Project" "project.godot" ".godot"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/.godot"
  [[ "$(count_exclusions)" -eq 1 ]]
}

# --- R ---

@test "renv: excludes renv when renv.lock is present" {
  create_project "Code/My-Project" "renv.lock" "renv"
  run_asimov
  assert_excluded "${HOME}/Code/My-Project/renv"
  [[ "$(count_exclusions)" -eq 1 ]]
}
