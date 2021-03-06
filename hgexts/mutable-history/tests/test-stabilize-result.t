  $ cat >> $HGRCPATH <<EOF
  > [defaults]
  > amend=-d "0 0"
  > [extensions]
  > hgext.rebase=
  > hgext.graphlog=
  > EOF
  $ echo "evolve=$(echo $(dirname $TESTDIR))/hgext/evolve.py" >> $HGRCPATH

  $ glog() {
  >   hg glog --template \
  >     '{rev}:{node|short}@{branch}({phase}) bk:[{bookmarks}] {desc|firstline}\n' "$@"
  > }

Test evolve removing the changeset being evolved

  $ hg init empty
  $ cd empty
  $ echo a > a
  $ hg ci -Am adda a
  $ echo b > b
  $ hg ci -Am addb b
  $ echo a >> a
  $ hg ci -m changea
  $ hg bookmark changea
  $ hg up 1
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo a >> a
  $ hg amend -m changea
  1 new unstable changesets
  $ hg evolve -v
  move:[2] changea
  atop:[4] changea
  hg rebase -r cce2c55b8965 -d fb9d051ec0a4
  resolving manifests
  $ glog --hidden
  @  4:fb9d051ec0a4@default(draft) bk:[changea] changea
  |
  | x  3:c5727dbded3c@default(draft) bk:[] temporary amend commit for 102a90ea7b4a
  | |
  | | x  2:cce2c55b8965@default(draft) bk:[] changea
  | |/
  | x  1:102a90ea7b4a@default(draft) bk:[] addb
  |/
  o  0:07f494440405@default(draft) bk:[] adda
  
  $ hg debugobsolete
  102a90ea7b4a3361e4082ed620918c261189a36a fb9d051ec0a450a4aa2ffc8c324979832ef88065 0 {'date': '* *', 'user': 'test'} (glob)
  c5727dbded3c3a6877cf60d6bb552a76812cb844 0 {'date': '* *', 'user': 'test'} (glob)
  cce2c55b896511e0b6e04173c9450ba822ebc740 0 {'date': '* *', 'user': 'test'} (glob)

Test evolve with conflict

  $ ls
  a
  b
  $ hg pdiff a
  diff -r 07f494440405 a
  --- a/a	* (glob)
  +++ b/a	* (glob)
  @@ -1,1 +1,2 @@
   a
  +a
  $ echo 'newer a' >> a
  $ hg ci -m 'newer a'
  $ hg gdown
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [4] changea
  $ echo 'a' > a
  $ hg amend
  1 new unstable changesets
  $ hg evolve
  move:[5] newer a
  atop:[7] changea
  merging a
  warning: conflicts during merge.
  merging a incomplete! (edit conflicts, then use 'hg resolve --mark')
  evolve failed!
  fix conflict and run "hg evolve --continue"
  abort: unresolved merge conflicts (see hg help resolve)
  [255]
  $ hg revert -r 'unstable()' a
  $ hg diff
  diff -r 66719795a494 a
  --- a/a	* (glob)
  +++ b/a	* (glob)
  @@ -1,1 +1,3 @@
   a
  +a
  +newer a
  $ hg evolve --continue
  grafting revision 5
  abort: unresolved merge conflicts (see hg help resolve)
  [255]
  $ hg resolve -m a
  $ hg evolve --continue
  grafting revision 5

Stabilize of late comer with different parent
==================================================

(the same parent case is handled in test-evolve.t)

  $ glog
  @  8:1cf0aacfd363@default(draft) bk:[] newer a
  |
  o  7:66719795a494@default(draft) bk:[changea] changea
  |
  o  0:07f494440405@default(draft) bk:[] adda
  
Add another commit

  $ hg gdown
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  [7] changea
  $ echo 'c' > c
  $ hg add c
  $ hg commit -m 'add c'
  created new head

Get a successors of 8 on it

  $ hg grab 8
  ? files updated, 0 files merged, 0 files removed, 0 files unresolved (glob)

Add real change to the successors

  $ echo 'babar' >> a
  $ hg amend

Make precursors public

  $ hg phase --hidden --public 8
  1 new bumped changesets
  $ glog
  @  12:(73b15c7566e9|d5c7ef82d003)@default\(draft\) bk:\[\] newer a (re)
  |
  o  9:7bc2f5967f5e@default(draft) bk:[] add c
  |
  | o  8:1cf0aacfd363@default(public) bk:[] newer a
  |/
  o  7:66719795a494@default(public) bk:[changea] changea
  |
  o  0:07f494440405@default(public) bk:[] adda
  

Stabilize !

  $ hg evolve --any --dry-run
  recreate:[12] newer a
  atop:[8] newer a
  hg rebase --rev (73b15c7566e9|d5c7ef82d003) --dest 66719795a494; (re)
  hg update 1cf0aacfd363;
  hg revert --all --rev (73b15c7566e9|d5c7ef82d003); (re)
  hg commit --msg "bumped update to %s" (no-eol)
  $ hg evolve --any
  recreate:[12] newer a
  atop:[8] newer a
  rebasing to destination parent: 66719795a494
  computing new diff
  commited as (a7cabd7bd9c2|671b9d7eeaec) (re)
  $ glog
  @  14:(a7cabd7bd9c2|671b9d7eeaec)@default\(draft\) bk:\[\] bumped update to 1cf0aacfd363: (re)
  |
  | o  9:7bc2f5967f5e@default(draft) bk:[] add c
  | |
  o |  8:1cf0aacfd363@default(public) bk:[] newer a
  |/
  o  7:66719795a494@default(public) bk:[changea] changea
  |
  o  0:07f494440405@default(public) bk:[] adda
  

Stabilize divergenent changesets with same parent
=================================================

  $ rm a.orig
  $ hg up 9
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cat << EOF >> a
  > flore
  > arthur
  > zephir
  > some
  > less
  > conflict
  > EOF
  $ hg ci -m 'More addition'
  $ glog
  @  15:3932c176bbaa@default(draft) bk:[] More addition
  |
  | o  14:(a7cabd7bd9c2|671b9d7eeaec)@default\(draft\) bk:\[\] bumped update to 1cf0aacfd363: (re)
  | |
  o |  9:7bc2f5967f5e@default(draft) bk:[] add c
  | |
  | o  8:1cf0aacfd363@default(public) bk:[] newer a
  |/
  o  7:66719795a494@default(public) bk:[changea] changea
  |
  o  0:07f494440405@default(public) bk:[] adda
  
  $ echo 'babar' >> a
  $ hg amend
  $ hg up --hidden 15
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  working directory parent is obsolete!
  $ mv a a.old
  $ echo 'jungle' > a
  $ cat a.old >> a
  $ rm a.old
  $ hg amend
  2 new divergent changesets
  $ glog
  @  19:eacc9c8240fe@default(draft) bk:[] More addition
  |
  | o  17:d2f173e25686@default(draft) bk:[] More addition
  |/
  | o  14:(a7cabd7bd9c2|671b9d7eeaec)@default\(draft\) bk:\[\] bumped update to 1cf0aacfd363: (re)
  | |
  o |  9:7bc2f5967f5e@default(draft) bk:[] add c
  | |
  | o  8:1cf0aacfd363@default(public) bk:[] newer a
  |/
  o  7:66719795a494@default(public) bk:[changea] changea
  |
  o  0:07f494440405@default(public) bk:[] adda
  

Stabilize It

  $ hg evolve -qn --traceback
  hg update -c eacc9c8240fe &&
  hg merge d2f173e25686 &&
  hg commit -m "auto merge resolving conflict between eacc9c8240fe and d2f173e25686"&&
  hg up -C 3932c176bbaa &&
  hg revert --all --rev tip &&
  hg commit -m "`hg log -r eacc9c8240fe --template={desc}`";
  $ hg evolve -v
  merge:[19] More addition
  with: [17] More addition
  base: [15] More addition
  merging divergent changeset
  resolving manifests
  merging a
  0 files updated, 1 files merged, 0 files removed, 0 files unresolved
  amending changeset eacc9c8240fe
  a
  copying changeset 283ccd10e2b8 to 7bc2f5967f5e
  a
  committed changeset 21:f344982e63c4
  $ hg st
  $ glog
  @  21:f344982e63c4@default(draft) bk:[] More addition
  |
  | o  14:(a7cabd7bd9c2|671b9d7eeaec)@default\(draft\) bk:\[\] bumped update to 1cf0aacfd363: (re)
  | |
  o |  9:7bc2f5967f5e@default(draft) bk:[] add c
  | |
  | o  8:1cf0aacfd363@default(public) bk:[] newer a
  |/
  o  7:66719795a494@default(public) bk:[changea] changea
  |
  o  0:07f494440405@default(public) bk:[] adda
  
  $ hg summary
  parent: 21:f344982e63c4 tip
   More addition
  branch: default
  commit: (clean)
  update: 2 new changesets, 2 branch heads (merge)
  $ hg export .
  # HG changeset patch
  # User test
  # Date 0 0
  #      Thu Jan 01 00:00:00 1970 +0000
  # Node ID f344982e63c462b1e44c0371c804685389e673a9
  # Parent  7bc2f5967f5e4ed277f60a89b7b04cc5d6407ced
  More addition
  
  diff -r 7bc2f5967f5e -r f344982e63c4 a
  --- a/a	Thu Jan 01 00:00:00 1970 +0000
  +++ b/a	Thu Jan 01 00:00:00 1970 +0000
  @@ -1,1 +1,9 @@
  +jungle
   a
  +flore
  +arthur
  +zephir
  +some
  +less
  +conflict
  +babar

Check conflict during divergence resolution
-------------------------------------------------

  $ hg up --hidden 15
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  working directory parent is obsolete!
  $ echo 'gotta break' >> a
  $ hg amend
  2 new divergent changesets
  $ hg phase 'divergent()'
  21: draft
  23: draft
  $ hg evolve -qn
  hg update -c 36e188246d67 &&
  hg merge f344982e63c4 &&
  hg commit -m "auto merge resolving conflict between 36e188246d67 and f344982e63c4"&&
  hg up -C 3932c176bbaa &&
  hg revert --all --rev tip &&
  hg commit -m "`hg log -r 36e188246d67 --template={desc}`";
  $ hg evolve
  merge:[23] More addition
  with: [21] More addition
  base: [15] More addition
  merging a
  warning: conflicts during merge.
  merging a incomplete! (edit conflicts, then use 'hg resolve --mark')
  0 files updated, 0 files merged, 0 files removed, 1 files unresolved
  use 'hg resolve' to retry unresolved file merges or 'hg update -C .' to abandon
  abort: Merge conflict between several amendments, and this is not yet automated
  (/!\ You can try:
  /!\ * manual merge + resolve => new cset X
  /!\ * hg up to the parent of the amended changeset (which are named W and Z)
  /!\ * hg revert --all -r X
  /!\ * hg ci -m "same message as the amended changeset" => new cset Y
  /!\ * hg kill -n Y W Z
  )
  [255]
