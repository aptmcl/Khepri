#!/usr/bin/env bash
# Build, and when credentials are present deploy, the docs for each package named
# in the $PACKAGES JSON array.
#
# Replaces the `julia-actions/julia-docdeploy@v1` step of the per-package docs
# jobs. That action is not used here because it cannot address a package in a
# subdirectory: at the v1 tag -- which is the same commit as v1.3.1, published
# 2023-03-29 -- action.yml declares exactly two inputs, `prefix` and
# `install-package`, and hardcodes `--project=docs/` with `include("docs/make.jl")`
# and no working-directory. A `project` input exists only on master (added
# 2024-07-18) and has never been released, so `with: project:` would be an unknown
# key, silently dropped. A workflow-level `defaults.run.working-directory` cannot
# rescue it either: defaults do not reach a composite action's own steps.
#
# Inlining the two commands costs only the GitHubActions.jl log formatter.
# cd-ing into the package directory reproduces the action's working directory
# exactly, so nothing is assumed about how Documenter resolves makedocs' `root`.
#
# Packages are built SEQUENTIALLY and deliberately. They now share one gh-pages
# branch, and deploydocs pushes with a plain `git push` and no rebase or retry, so
# concurrent deploys race and the losers are rejected outright.
set -uo pipefail

: "${PACKAGES:?PACKAGES must be a JSON array of package names}"

failed=()

for pkg in $(printf '%s' "$PACKAGES" | python3 -c 'import json,sys; print("\n".join(json.load(sys.stdin)))'); do
  echo "::group::docs ${pkg}"
  if (
    set -e
    julia --color=yes --project="Julia/${pkg}/docs" \
      .github/scripts/dev_siblings.jl "${pkg}" --with-self
    julia --color=yes --project="Julia/${pkg}/docs" -e 'using Pkg; Pkg.instantiate()'
    cd "Julia/${pkg}"
    julia --color=yes --project=docs docs/make.jl
  ); then
    echo "docs ${pkg}: ok"
  else
    echo "::error::docs build failed for ${pkg}"
    failed+=("${pkg}")
  fi
  echo "::endgroup::"
done

if [ ${#failed[@]} -ne 0 ]; then
  echo "::error::docs failed for: ${failed[*]}"
  exit 1
fi
