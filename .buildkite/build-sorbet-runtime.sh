#!/bin/bash

set -eo pipefail

pushd gems/sorbet-runtime

echo "--- setup :ruby:"
eval "$(rbenv init -)"

runtime_versions=(2.7.7 3.1.2)

for runtime_version in "${runtime_versions[@]}"; do
  rbenv install --skip-existing "$runtime_version"
  rbenv shell "$runtime_version"
  rbenv exec bundle config set path 'vendor/bundle'
  rbenv exec bundle install
done

for runtime_version in "${runtime_versions[@]}"; do
  rbenv shell "$runtime_version"

  rbenv exec ruby --version

  failed=

  if [ "$runtime_version" = "2.7.7" ]; then
    # Our Rubocop version doesn't understand Ruby 3.1 as a valid Ruby version
    echo "+++ rubocop ($runtime_version)"
    if ! rbenv exec bundle exec rake rubocop; then
      failed=1
    fi
  fi

  echo "+++ tests ($runtime_version)"
  if ! rbenv exec bundle exec rake test; then
    failed=1
  fi

  pushd test/wholesome

  rbenv exec bundle config set path 'vendor/bundle'
  rbenv exec bundle install

  if ! rbenv exec bundle exec rake test; then
    failed=1
  fi

  popd

  if [ "$failed" != "" ]; then
    exit 1
  fi
done

echo "--- build"
git_commit_count=$(git rev-list --count HEAD)
sed -i.bak release_version="0.5.${git_commit_count}"
sed "s/0\\.0\\.0/${release_version}/" sorbet-runtime.gemspec
gem build sorbet-runtime.gemspec
popd

rm -rf _out_
mkdir -p _out_/gems/
cp gems/sorbet-runtime/sorbet-runtime-*.gem _out_/gems/
