# Rename master → main

Required for `dart pub get` to work without a `ref:` key in consumer pubspecs,
since GitLab's default branch is `main`.

## Steps

```bash
# 1. Rename local branch
git branch -m master main

# 2. Push new branch name
git push swisseph.dart-gitlab main

# 3. Delete old remote branch
git push swisseph.dart-gitlab --delete master
```

Then on GitLab: **Settings → Repository → Default branch** → set to `main`.

## After

Update any local git config if needed:
```bash
git branch --set-upstream-to=swisseph.dart-gitlab/main main
```
