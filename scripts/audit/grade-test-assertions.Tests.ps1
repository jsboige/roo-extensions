# Pester fixture for grade-test-assertions.cjs (#833 arbitration 2026-09-24:
# non-negated toBeNull/toBeUndefined -> MEDIUM, their .not. forms -> WEAK,
# MATCHER_RE reads .not. so the two forms are no longer the same class).
# Run: powershell -NoProfile -ExecutionPolicy Bypass -File grade-test-assertions.Tests.ps1
# (or Invoke-Pester on this file). PowerShell 5.1 and 7 both supported.

BeforeAll {
    $Script:FixtureDir = Join-Path ([System.IO.Path]::GetTempPath()) ("grader-fixture-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $Script:FixtureDir | Out-Null

    # Mixed classes, counts chosen by hand:
    #   medium: toBeNull x2, toBeUndefined x1
    #   weak:   not.toBeNull x3, not.toBeUndefined x2, toBeFalsy x1, toBeDefined x1
    #   strong: toBe x2, toEqual x1  => total 13, weakPct 53.8 -> F
    $Mixed = @'
it('mixed', () => {
  expect(a).toBeNull();
  expect(b).toBeNull();
  expect(c).not.toBeNull();
  expect(d).not.toBeNull();
  expect(e).not.toBeNull();
  expect(f).toBeUndefined();
  expect(g).not.toBeUndefined();
  expect(h).not.toBeUndefined();
  expect(i).toBeFalsy();
  expect(j).toBeDefined();
  expect(k).toBe(1);
  expect(l).toBe(2);
  expect(m).toEqual({});
});
'@
    Set-Content -Path (Join-Path $Script:FixtureDir 'mixed.test.ts') -Value $Mixed -Encoding ascii

    # Identity contracts only, NON-negated: pre-fix these graded 40% weak (D);
    # post-fix weak=0 -> A. This is the discriminating case of the arbitration.
    $IdentityOnly = @'
it('identity-only', () => {
  expect(a).toBeNull();
  expect(b).toBeNull();
  expect(c).toBeNull();
  expect(d).toBeNull();
  expect(e).toBeNull();
  expect(f).toBeUndefined();
  expect(g).toBeUndefined();
  expect(h).toBeUndefined();
  expect(i).toBe(1);
  expect(j).toBe(2);
  expect(k).toBe(3);
  expect(l).toBe(4);
  expect(m).toBe(5);
  expect(n).toBe(6);
  expect(o).toBe(7);
  expect(p).toBe(8);
  expect(q).toEqual({});
  expect(r).toEqual([]);
  expect(s).toEqual('');
  expect(t).toEqual(0);
});
'@
    Set-Content -Path (Join-Path $Script:FixtureDir 'identity-only.test.ts') -Value $IdentityOnly -Encoding ascii

    $Script:OutFile = Join-Path $Script:FixtureDir 'out.json'
    # Join-Path: the fixture runs on ubuntu-latest in CI, where a literal
    # backslash in "$PSScriptRoot\..." is not a path separator.
    $Script:Stdout = node (Join-Path $PSScriptRoot 'grade-test-assertions.cjs') --dir $Script:FixtureDir --json --out $Script:OutFile
    $Script:Summary = $Script:Stdout | ConvertFrom-Json
}

AfterAll {
    if (Test-Path $Script:FixtureDir) { Remove-Item -Recurse -Force $Script:FixtureDir }
}

Describe 'grade-test-assertions — #833 identity-matcher reclassification' {
    It 'mixed fixture: per-class counts (medium 3 / weak 7 / strong 3), weakPct 53.8, grade F' {
        $Row = $Script:Summary.results | Where-Object { $_.file -like '*mixed.test.ts' }
        $Row | Should -Not -BeNullOrEmpty
        $Row.weak | Should -Be 7
        $Row.medium | Should -Be 3
        $Row.strong | Should -Be 3
        $Row.assertions | Should -Be 13
        $Row.weakPct | Should -Be 53.8
        $Row.grade | Should -Be 'F'
    }

    It 'negated identity counted weak AND labelled with .not. in weakSamples' {
        $Row = $Script:Summary.results | Where-Object { $_.file -like '*mixed.test.ts' }
        ($Row.weakSamples | Where-Object { $_ -like '*.not.toBeNull' }) | Should -Not -BeNullOrEmpty
        ($Row.weakSamples | Where-Object { $_ -like '*.not.toBeUndefined' }) | Should -Not -BeNullOrEmpty
    }

    It 'non-negated identity contracts no longer weak: weak 0, medium 8, grade A (was D pre-fix)' {
        $Row = $Script:Summary.results | Where-Object { $_.file -like '*identity-only.test.ts' }
        $Row | Should -Not -BeNullOrEmpty
        $Row.weak | Should -Be 0
        $Row.medium | Should -Be 8
        $Row.strong | Should -Be 12
        $Row.weakPct | Should -Be 0
        $Row.grade | Should -Be 'A'
    }

    It '--out flag honored (file written next to fixtures, default audit output untouched)' {
        Test-Path $Script:OutFile | Should -BeTrue
        (Get-Content $Script:OutFile -Raw | ConvertFrom-Json).files | Should -Be 2
    }
}
