  $ cat >> $HGRCPATH <<EOF
  > [ui]
  > logtemplate={rev}:{node|short}[{bookmarks}] ({obsolete}/{phase}) {desc|firstline}\n
  > [extensions]
  > hgext.rebase=
  > EOF
  $ echo "evolve=$(echo $(dirname $TESTDIR))/hgext/evolve.py" >> $HGRCPATH

  $ mkcommit() {
  >    echo "$1" > "$1"
  >    hg add "$1"
  >    hg ci -m "add $1"
  > }

  $ hg init repo
  $ cd repo
  $ mkcommit a
  $ hg phase --public .
  $ mkcommit b
  $ mkcommit c
  $ mkcommit d
  $ mkcommit e
  $ hg bookmarks BABAR
  $ hg log -G
  @  4:9d206ffc875e[BABAR] (stable/draft) add e
  |
  o  3:47d2a3944de8[] (stable/draft) add d
  |
  o  2:4538525df7e2[] (stable/draft) add c
  |
  o  1:7c3bad9141dc[] (stable/draft) add b
  |
  o  0:1f0dee641bb7[] (stable/public) add a
  

Check simple case
----------------------------

prune current and tip changeset

  $ hg prune --user blah --date '1979-12-15' .
  1 changesets pruned
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  working directory now at 47d2a3944de8
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)

prune leaving unstability behind

  $ hg prune 1
  1 changesets pruned
  2 new unstable changesets
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)

pruning multiple changeset at once

  $ hg prune 2:
  2 changesets pruned
  0 files updated, 0 files merged, 3 files removed, 0 files unresolved
  working directory now at 1f0dee641bb7
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)

cannot prune public changesets

  $ hg prune 0
  abort: cannot prune immutable changeset: 1f0dee641bb7
  (see "hg help phases" for details)
  [255]
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)

Check successors addition
----------------------------

  $ mkcommit bb
  $ mkcommit cc
  $ mkcommit dd
  $ mkcommit ee
  $ hg up 0
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ mkcommit nB
  created new head
  $ mkcommit nC
  $ mkcommit nD
  $ mkcommit nE

  $ hg log -G
  @  12:6e8148413dd5[] (stable/draft) add nE
  |
  o  11:8ee176ff1d4b[] (stable/draft) add nD
  |
  o  10:aa96dc3f04c2[] (stable/draft) add nC
  |
  o  9:6f6f25e4f748[] (stable/draft) add nB
  |
  | o  8:bb5e90a7ea1f[] (stable/draft) add ee
  | |
  | o  7:00ded550b1e2[] (stable/draft) add dd
  | |
  | o  6:354011cd103f[] (stable/draft) add cc
  | |
  | o  5:814c38b95e72[] (stable/draft) add bb
  |/
  o  0:1f0dee641bb7[BABAR] (stable/public) add a
  

one old, one new

  $ hg prune 'desc("add ee")' -s 'desc("add nE")'
  1 changesets pruned
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)
  bb5e90a7ea1f3b4b38b23150a4a597b6146d70ef 6e8148413dd541855b72a920a90c06fca127c7e7 0 {'date': '*', 'user': 'test'} (glob)
  $ hg log -G
  @  12:6e8148413dd5[] (stable/draft) add nE
  |
  o  11:8ee176ff1d4b[] (stable/draft) add nD
  |
  o  10:aa96dc3f04c2[] (stable/draft) add nC
  |
  o  9:6f6f25e4f748[] (stable/draft) add nB
  |
  | o  7:00ded550b1e2[] (stable/draft) add dd
  | |
  | o  6:354011cd103f[] (stable/draft) add cc
  | |
  | o  5:814c38b95e72[] (stable/draft) add bb
  |/
  o  0:1f0dee641bb7[BABAR] (stable/public) add a
  

one old, two new

  $ hg prune 'desc("add dd")' -s 'desc("add nD")' -s 'desc("add nC")'
  1 changesets pruned
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)
  bb5e90a7ea1f3b4b38b23150a4a597b6146d70ef 6e8148413dd541855b72a920a90c06fca127c7e7 0 {'date': '*', 'user': 'test'} (glob)
  00ded550b1e28bba454bd34cec1269d22cf3ef25 aa96dc3f04c2c2341fe6880aeb6dc9fbffff9ef9 8ee176ff1d4b2034ce51e3efc579c2de346b631d 0 {'date': '**', 'user': 'test'} (glob)
  $ hg log -G
  @  12:6e8148413dd5[] (stable/draft) add nE
  |
  o  11:8ee176ff1d4b[] (stable/draft) add nD
  |
  o  10:aa96dc3f04c2[] (stable/draft) add nC
  |
  o  9:6f6f25e4f748[] (stable/draft) add nB
  |
  | o  6:354011cd103f[] (stable/draft) add cc
  | |
  | o  5:814c38b95e72[] (stable/draft) add bb
  |/
  o  0:1f0dee641bb7[BABAR] (stable/public) add a
  

two old, two new (should be denied)

  $ hg prune 'desc("add cc")' 'desc("add bb")' -s 'desc("add nD")' -s 'desc("add nC")'
  abort: Can't use multiple successors for multiple precursors
  [255]
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)
  bb5e90a7ea1f3b4b38b23150a4a597b6146d70ef 6e8148413dd541855b72a920a90c06fca127c7e7 0 {'date': '*', 'user': 'test'} (glob)
  00ded550b1e28bba454bd34cec1269d22cf3ef25 aa96dc3f04c2c2341fe6880aeb6dc9fbffff9ef9 8ee176ff1d4b2034ce51e3efc579c2de346b631d 0 {'date': '**', 'user': 'test'} (glob)

two old, one new:

  $ hg prune 'desc("add cc")' 'desc("add bb")' -s 'desc("add nB")'
  2 changesets pruned
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)
  bb5e90a7ea1f3b4b38b23150a4a597b6146d70ef 6e8148413dd541855b72a920a90c06fca127c7e7 0 {'date': '*', 'user': 'test'} (glob)
  00ded550b1e28bba454bd34cec1269d22cf3ef25 aa96dc3f04c2c2341fe6880aeb6dc9fbffff9ef9 8ee176ff1d4b2034ce51e3efc579c2de346b631d 0 {'date': '**', 'user': 'test'} (glob)
  814c38b95e72dfe2cbf675b1649ea9d780c89a80 6f6f25e4f748d8f7571777e6e168aedf50350ce8 0 {'date': '*', 'user': 'test'} (glob)
  354011cd103f58bbbd9091a3cee6d6a6bd0dddf7 6f6f25e4f748d8f7571777e6e168aedf50350ce8 0 {'date': '*', 'user': 'test'} (glob)

two old, two new with --biject

  $ hg up 0
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ mkcommit n1
  created new head
  $ mkcommit n2

  $ hg prune 'desc("add n1")::desc("add n2")' -s 'desc("add nD")::desc("add nE")' --biject
  2 changesets pruned
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  working directory now at 1f0dee641bb7
  $ hg debugobsolete
  9d206ffc875e1bc304590549be293be36821e66c 0 {'date': '314064000 0', 'user': 'blah'} (glob)
  7c3bad9141dcb46ff89abf5f61856facd56e476c 0 {'date': '*', 'user': 'test'} (glob)
  4538525df7e2b9f09423636c61ef63a4cb872a2d 0 {'date': '*', 'user': 'test'} (glob)
  47d2a3944de8b013de3be9578e8e344ea2e6c097 0 {'date': '*', 'user': 'test'} (glob)
  bb5e90a7ea1f3b4b38b23150a4a597b6146d70ef 6e8148413dd541855b72a920a90c06fca127c7e7 0 {'date': '*', 'user': 'test'} (glob)
  00ded550b1e28bba454bd34cec1269d22cf3ef25 aa96dc3f04c2c2341fe6880aeb6dc9fbffff9ef9 8ee176ff1d4b2034ce51e3efc579c2de346b631d 0 {'date': '**', 'user': 'test'} (glob)
  814c38b95e72dfe2cbf675b1649ea9d780c89a80 6f6f25e4f748d8f7571777e6e168aedf50350ce8 0 {'date': '* *', 'user': 'test'} (glob)
  354011cd103f58bbbd9091a3cee6d6a6bd0dddf7 6f6f25e4f748d8f7571777e6e168aedf50350ce8 0 {'date': '* *', 'user': 'test'} (glob)
  cb7f8f706a6532967b98cf8583a81baab79a0fa7 8ee176ff1d4b2034ce51e3efc579c2de346b631d 0 {'date': '* *', 'user': 'test'} (glob)
  21b6f2f1cece8c10326e575dd38239189d467190 6e8148413dd541855b72a920a90c06fca127c7e7 0 {'date': '* *', 'user': 'test'} (glob)

test hg prune -B bookmark
yoinked from test-mq-strip.t

  $ cd ..
  $ hg init bookmarks
  $ cd bookmarks
  $ hg debugbuilddag '..<2.*1/2:m<2+3:c<m+3:a<2.:b'
  $ hg bookmark -r 'a' 'todelete'
  $ hg bookmark -r 'b' 'B'
  $ hg bookmark -r 'b' 'nostrip'
  $ hg bookmark -r 'c' 'delete'
  $ hg up -C todelete
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ hg prune -B nostrip
  bookmark 'nostrip' deleted
  abort: nothing to prune
  [255]
  $ hg tag --remove --local a
  $ hg prune -B todelete
  1 changesets pruned
  0 files updated, 0 files merged, 0 files removed, 0 files unresolved
  working directory now at d62d843c9a01
  bookmark 'todelete' deleted
  $ hg id -ir dcbb326fdec2
  abort: unknown revision 'dcbb326fdec2'!
  [255]
  $ hg id -ir d62d843c9a01
  d62d843c9a01
  $ hg bookmarks
     B                         10:ff43616e5d0f
     delete                    6:2702dd0c91e7
  $ hg prune -B delete
  3 changesets pruned
  bookmark 'delete' deleted
  $ hg tag --remove --local c
  $ hg id -ir 6:2702dd0c91e7
  abort: unknown revision '2702dd0c91e7'!
  [255]

