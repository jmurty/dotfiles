  $ cat >> $HGRCPATH <<EOF
  > [defaults]
  > amend=-d "0 0"
  > [extensions]
  > hgext.rebase=
  > hgext.graphlog=
  > EOF
  $ echo "evolve=$(echo $(dirname $TESTDIR))/hgext/evolve.py" >> $HGRCPATH

  $ glog() {
  >   hg glog --template '{rev}@{branch}({phase}) {desc|firstline}\n' "$@"
  > }

  $ hg init repo --traceback
  $ cd repo
  $ echo a > a
  $ hg ci -Am adda
  adding a

Test amend captures branches

  $ hg branch foo
  marked working directory as branch foo
  (branches are permanent and global, did you want a bookmark?)
  $ hg amend
  $ hg debugobsolete
  07f4944404050f47db2e5c5071e0e84e7a27bba9 6a022cbb61d5ba0f03f98ff2d36319dfea1034ae 0 {'date': '* *', 'user': 'test'} (glob)
  b2e32ffb533cbe1d5759638c0cd4e8abc43b2738 0 {'date': '* *', 'user': 'test'} (glob)
  $ hg branch
  foo
  $ hg branches
  foo                            2:6a022cbb61d5
  $ glog
  @  2@foo(draft) adda
  
Test no-op

  $ hg amend
  nothing changed
  [1]
  $ glog
  @  2@foo(draft) adda
  

Test forcing the message to the same value, no intermediate revision.

  $ hg amend -m 'adda'
  nothing changed
  [1]
  $ glog
  @  2@foo(draft) adda
  

Test collapsing into an existing revision, no intermediate revision.

  $ echo a >> a
  $ hg ci -m changea
  $ echo a > a
  $ hg status
  M a
  $ hg pstatus
  $ hg diff
  diff -r f7a50201fe3a a
  --- a/a	Thu Jan 01 00:00:00 1970 +0000
  +++ b/a	* +0000 (glob)
  @@ -1,2 +1,1 @@
   a
  -a
  $ hg pdiff
  $ hg ci -m reseta
  $ hg debugobsolete
  07f4944404050f47db2e5c5071e0e84e7a27bba9 6a022cbb61d5ba0f03f98ff2d36319dfea1034ae 0 {'date': '* *', 'user': 'test'} (glob)
  b2e32ffb533cbe1d5759638c0cd4e8abc43b2738 0 {'date': '* *', 'user': 'test'} (glob)
  $ hg phase 2
  2: draft
  $ glog
  @  4@foo(draft) reseta
  |
  o  3@foo(draft) changea
  |
  o  2@foo(draft) adda
  

