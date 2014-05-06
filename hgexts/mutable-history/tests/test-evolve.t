  $ cat >> $HGRCPATH <<EOF
  > [defaults]
  > amend=-d "0 0"
  > fold=-d "0 0"
  > [web]
  > push_ssl = false
  > allow_push = *
  > [phases]
  > publish = False
  > [alias]
  > qlog = log --template='{rev} - {node|short} {desc} ({phase})\n'
  > [diff]
  > git = 1
  > unified = 0
  > [extensions]
  > hgext.rebase=
  > hgext.graphlog=
  > EOF
  $ echo "evolve=$(echo $(dirname $TESTDIR))/hgext/evolve.py" >> $HGRCPATH
  $ mkcommit() {
  >    echo "$1" > "$1"
  >    hg add "$1"
  >    hg ci -m "add $1"
  > }

  $ glog() {
  >   hg glog --template '{rev}:{node|short}@{branch}({phase}) {desc|firstline}\n' "$@"
  > }

various init

  $ hg init local
  $ cd local
  $ mkcommit a
  $ mkcommit b
  $ cat >> .hg/hgrc << EOF
  > [phases]
  > publish = True
  > EOF
  $ hg pull -q . # make 1 public
  $ rm .hg/hgrc
  $ mkcommit c
  $ mkcommit d
  $ hg up 1
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ mkcommit e -q
  created new head
  $ mkcommit f
  $ hg qlog
  5 - e44648563c73 add f (draft)
  4 - fbb94e3a0ecf add e (draft)
  3 - 47d2a3944de8 add d (draft)
  2 - 4538525df7e2 add c (draft)
  1 - 7c3bad9141dc add b (public)
  0 - 1f0dee641bb7 add a (public)

test kill and immutable changeset

  $ hg log -r 1 --template '{rev} {phase} {obsolete}\n'
  1 public stable
  $ hg kill 1
  abort: cannot prune immutable changeset: 7c3bad9141dc
  (see "hg help phases" for details)
  [255]
  $ hg log -r 1 --template '{rev} {phase} {obsolete}\n'
  1 public stable

test simple kill

  $ hg id -n
  5
  $ hg kill .
  1 changesets pruned
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  working directory now at fbb94e3a0ecf
  $ hg qlog
  4 - fbb94e3a0ecf add e (draft)
  3 - 47d2a3944de8 add d (draft)
  2 - 4538525df7e2 add c (draft)
  1 - 7c3bad9141dc add b (public)
  0 - 1f0dee641bb7 add a (public)

test multiple kill

  $ hg kill 4 -r 3
  2 changesets pruned
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  working directory now at 7c3bad9141dc
  $ hg qlog
  2 - 4538525df7e2 add c (draft)
  1 - 7c3bad9141dc add b (public)
  0 - 1f0dee641bb7 add a (public)

test kill with dirty changes

  $ hg up 2
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ echo 4 > g
  $ hg add g
  $ hg kill .
  1 changesets pruned
  0 files updated, 0 files merged, 1 files removed, 0 files unresolved
  working directory now at 7c3bad9141dc
  $ hg st
  A g
  $ cd ..

##########################
importing Parren test
##########################

  $ cat << EOF >> $HGRCPATH
  > [ui]
  > logtemplate = "{rev}\t{bookmarks}: {desc|firstline} - {author|user}\n"
  > EOF

Creating And Updating Changeset
===============================

Setup the Base Repo
-------------------

We start with a plain base repo::

  $ hg init main; cd main
  $ cat >main-file-1 <<-EOF
  > One
  > 
  > Two
  > 
  > Three
  > EOF
  $ echo Two >main-file-2
  $ hg add
  adding main-file-1
  adding main-file-2
  $ hg commit --message base
  $ cd ..

and clone this into a new repo where we do our work::

  $ hg clone main work
  updating to branch default
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ cd work


Create First Patch
------------------

To begin with, we just do the changes that will be the initial version of the changeset::

  $ echo One >file-from-A
  $ sed -i'' -e s/One/Eins/ main-file-1
  $ hg add file-from-A

So this is what we would like our changeset to be::

  $ hg diff
  diff --git a/file-from-A b/file-from-A
  new file mode 100644
  --- /dev/null
  +++ b/file-from-A
  @@ -0,0 +1,1 @@
  +One
  diff --git a/main-file-1 b/main-file-1
  --- a/main-file-1
  +++ b/main-file-1
  @@ -1,1 +1,1 @@
  -One
  +Eins

To commit it we just - commit it::

  $ hg commit --message "a nifty feature"

and place a bookmark so we can easily refer to it again (which we could have done before the commit)::

  $ hg book feature-A


Create Second Patch
-------------------

Let's do this again for the second changeset::

  $ echo Two >file-from-B
  $ sed -i'' -e s/Two/Zwie/ main-file-1
  $ hg add file-from-B

Before committing, however, we need to switch to a new bookmark for the second
changeset. Otherwise we would inadvertently move the bookmark for our first changeset.
It is therefore advisable to always set the bookmark before committing::

  $ hg book feature-B
  $ hg commit --message "another feature"

So here we are::

  $ hg book
     feature-A                 1:568a468b60fc
   * feature-B                 2:7b36850622b2


Fix The Second Patch
--------------------

There's a typo in feature-B. We spelled *Zwie* instead of *Zwei*::

  $ hg diff --change tip | grep -F Zwie
  +Zwie

Fixing this is very easy. Just change::

  $ sed -i'' -e s/Zwie/Zwei/ main-file-1

and **amend**::

  $ hg amend

This results in a new single changeset for our amended changeset, and the old
changeset plus the updating changeset are hidden from view by default::

  $ hg log
  4	feature-B: another feature - test
  1	feature-A: a nifty feature - test
  0	: base - test

  $ hg up feature-A -q
  $ hg bookmark -i feature-A
  $ sed -i'' -e s/Eins/Un/ main-file-1

(amend of public changeset denied)

  $ hg phase --public 0 -v
  phase changed for 1 changesets


(amend of on ancestors)

  $ hg amend
  1 new unstable changesets
  $ hg log
  6	feature-A: a nifty feature - test
  4	feature-B: another feature - test
  1	: a nifty feature - test
  0	: base - test
  $ hg up -q 0
  $ glog --hidden
  o  6:ba0ec09b1bab@default(draft) a nifty feature
  |
  | x  5:c296b79833d1@default(draft) temporary amend commit for 568a468b60fc
  | |
  | | o  4:207cbc4ea7fe@default(draft) another feature
  | |/
  | | x  3:5bb880fc0f12@default(draft) temporary amend commit for 7b36850622b2
  | | |
  | | x  2:7b36850622b2@default(draft) another feature
  | |/
  | x  1:568a468b60fc@default(draft) a nifty feature
  |/
  @  0:e55e0562ee93@default(public) base
  
  $ hg debugobsolete
  7b36850622b2fd159fa30a4fb2a1edd2043b4a14 207cbc4ea7fee30d18b3a25f534fe5db22c6071b 0 {'date': '* *', 'user': 'test'} (glob)
  5bb880fc0f12dd61eee6de36f62b93fdbc3684b0 0 {'date': '* *', 'user': 'test'} (glob)
  568a468b60fc99a42d5d4ddbe181caff1eef308d ba0ec09b1babf3489b567853807f452edd46704f 0 {'date': '* *', 'user': 'test'} (glob)
  c296b79833d1d497f33144786174bf35e04e44a3 0 {'date': '* *', 'user': 'test'} (glob)
  $ hg evolve
  move:[4] another feature
  atop:[6] a nifty feature
  merging main-file-1
  $ hg log
  7	feature-B: another feature - test
  6	feature-A: a nifty feature - test
  0	: base - test

Test commit -o options

  $ hg up 6
  1 files updated, 0 files merged, 1 files removed, 0 files unresolved
  $ hg revert -r 7 --all
  adding file-from-B
  reverting main-file-1
  $ sed -i'' -e s/Zwei/deux/ main-file-1
  $ hg commit -m 'another feature that rox' -o 7
  created new head
  $ hg log
  8	feature-B: another feature that rox - test
  6	feature-A: a nifty feature - test
  0	: base - test

phase change turning obsolete changeset public issue a bumped warning

  $ hg phase --hidden --public 7
  1 new bumped changesets

all solving bumped troubled

  $ hg glog
  @  8	feature-B: another feature that rox - test
  |
  | o  7	: another feature - test
  |/
  o  6	feature-A: a nifty feature - test
  |
  o  0	: base - test
  
  $ hg evolve --any --traceback
  recreate:[8] another feature that rox
  atop:[7] another feature
  computing new diff
  commited as ca3b75e3e59b
  $ hg glog
  @  9	feature-B: bumped update to abe98aeaaa35: - test
  |
  o  7	: another feature - test
  |
  o  6	feature-A: a nifty feature - test
  |
  o  0	: base - test
  
  $ hg diff --hidden -r 9 -r 8
  $ hg diff -r 9^ -r 9
  diff --git a/main-file-1 b/main-file-1
  --- a/main-file-1
  +++ b/main-file-1
  @@ -3,1 +3,1 @@
  -Zwei
  +deux
  $ hg log -r 'bumped()' # no more bumped

test evolve --all
  $ sed -i'' -e s/deux/to/ main-file-1
  $ hg commit -m 'dansk 2!'
  $ sed -i'' -e s/Three/tre/ main-file-1
  $ hg commit -m 'dansk 3!'
  $ hg update 9
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ sed -i'' -e s/Un/Én/ main-file-1
  $ hg commit --amend -m 'dansk!'
  2 new unstable changesets

  $ hg evolve --all --traceback
  move:[10] dansk 2!
  atop:[13] dansk!
  merging main-file-1
  move:[11] dansk 3!
  atop:[14] dansk 2!
  merging main-file-1
  $ hg glog
  @  15	: dansk 3! - test
  |
  o  14	: dansk 2! - test
  |
  o  13	feature-B: dansk! - test
  |
  o  7	: another feature - test
  |
  o  6	feature-A: a nifty feature - test
  |
  o  0	: base - test
  

  $ cd ..

enable general delta

  $ cat << EOF >> $HGRCPATH
  > [format]
  > generaldelta=1
  > EOF



  $ hg init alpha
  $ cd alpha
  $ echo 'base' > firstfile
  $ hg add firstfile
  $ hg ci -m 'base'

  $ cd ..
  $ hg clone -Ur 0 alpha beta
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  $ cd alpha

  $ cat << EOF > A
  > We
  > need
  > some
  > kind
  > of 
  > file
  > big
  > enough
  > to
  > prevent
  > snapshot
  > .
  > yes
  > new
  > lines
  > are
  > useless
  > .
  > EOF
  $ hg add A
  $ hg commit -m 'adding A'
  $ hg mv A B
  $ echo '.' >> B
  $ hg amend -m 'add B'
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  3 files, 4 changesets, 4 total revisions
  $ hg --config extensions.hgext.mq= strip 'extinct()'
  abort: empty revision set
  [255]
  $ hg --config extensions.hgext.mq= strip --hidden 'extinct()'
  saved backup bundle to $TESTTMP/alpha/.hg/strip-backup/e87767087a57-backup.hg
  $ hg verify
  checking changesets
  checking manifests
  crosschecking files in changesets and manifests
  checking files
  2 files, 2 changesets, 2 total revisions
  $ cd ..

Clone just this branch

  $ cd beta
  $ hg pull -r tip ../alpha
  pulling from ../alpha
  searching for changes
  adding changesets
  adding manifests
  adding file changes
  added 1 changesets with 1 changes to 1 files
  (run 'hg update' to get a working copy)
  $ hg up
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved

  $ cd ..

Test graft --obsolete/--old-obsolete

  $ hg init test-graft
  $ cd test-graft
  $ mkcommit 0
  $ mkcommit 1
  $ mkcommit 2
  $ mkcommit 3
  $ hg up -qC 0
  $ mkcommit 4
  created new head
  $ glog --hidden
  @  4:ce341209337f@default(draft) add 4
  |
  | o  3:0e84df4912da@default(draft) add 3
  | |
  | o  2:db038628b9e5@default(draft) add 2
  | |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg graft -r3 -O
  grafting revision 3
  $ hg graft -r1 -o 2
  grafting revision 1
  $ glog --hidden
  @  6:acb28cd497b7@default(draft) add 1
  |
  o  5:0b9e50c35132@default(draft) add 3
  |
  o  4:ce341209337f@default(draft) add 4
  |
  | x  3:0e84df4912da@default(draft) add 3
  | |
  | x  2:db038628b9e5@default(draft) add 2
  | |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg debugobsolete
  0e84df4912da4c7cad22a3b4fcfd58ddfb7c8ae9 0b9e50c35132ff548ec0065caea6a87e1ebcef32 0 {'date': '* *', 'user': 'test'} (glob)
  db038628b9e56f51a454c0da0c508df247b41748 acb28cd497b7f8767e01ef70f68697a959573c2d 0 {'date': '* *', 'user': 'test'} (glob)

Test graft --continue

  $ hg up -qC 0
  $ echo 2 > 1
  $ hg ci -Am conflict 1
  created new head
  $ hg up -qC 6
  $ hg graft -O 7
  grafting revision 7
  merging 1
  warning: conflicts during merge.
  merging 1 incomplete! (edit conflicts, then use 'hg resolve --mark')
  abort: unresolved conflicts, can't continue
  (use hg resolve and hg graft --continue)
  [255]
  $ hg log -r7 --template '{rev}:{node|short} {obsolete}\n'
  7:a5bfd90a2f29 stable
  $ echo 3 > 1
  $ hg resolve -m 1
  $ hg graft --continue -O
  grafting revision 7
  $ glog --hidden
  @  8:920e58bb443b@default(draft) conflict
  |
  | x  7:a5bfd90a2f29@default(draft) conflict
  | |
  o |  6:acb28cd497b7@default(draft) add 1
  | |
  o |  5:0b9e50c35132@default(draft) add 3
  | |
  o |  4:ce341209337f@default(draft) add 4
  |/
  | x  3:0e84df4912da@default(draft) add 3
  | |
  | x  2:db038628b9e5@default(draft) add 2
  | |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg debugobsolete
  0e84df4912da4c7cad22a3b4fcfd58ddfb7c8ae9 0b9e50c35132ff548ec0065caea6a87e1ebcef32 0 {'date': '* *', 'user': 'test'} (glob)
  db038628b9e56f51a454c0da0c508df247b41748 acb28cd497b7f8767e01ef70f68697a959573c2d 0 {'date': '* *', 'user': 'test'} (glob)
  a5bfd90a2f29c7ccb8f917ff4e5013a9053d0a04 920e58bb443b73eea9d6d65570b4241051ea3229 0 {'date': '* *', 'user': 'test'} (glob)

Test touch

  $ glog
  @  8:920e58bb443b@default(draft) conflict
  |
  o  6:acb28cd497b7@default(draft) add 1
  |
  o  5:0b9e50c35132@default(draft) add 3
  |
  o  4:ce341209337f@default(draft) add 4
  |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg touch
  $ glog
  @  9:*@default(draft) conflict (glob)
  |
  o  6:acb28cd497b7@default(draft) add 1
  |
  o  5:0b9e50c35132@default(draft) add 3
  |
  o  4:ce341209337f@default(draft) add 4
  |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg touch .
  $ glog
  @  10:*@default(draft) conflict (glob)
  |
  o  6:acb28cd497b7@default(draft) add 1
  |
  o  5:0b9e50c35132@default(draft) add 3
  |
  o  4:ce341209337f@default(draft) add 4
  |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  

Test fold

  $ rm *.orig
  $ hg fold
  no revision to fold
  [1]
  $ hg fold 6 --rev 10
  abort: cannot specify both --rev and a target revision
  [255]
  $ hg fold 6 # want to run hg fold 6
  2 changesets folded
  1 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ glog
  @  11:dd4682c1a481@default(draft) add 1
  |
  o  5:0b9e50c35132@default(draft) add 3
  |
  o  4:ce341209337f@default(draft) add 4
  |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg log -r 11 --template '{desc}\n'
  add 1
  
  
  conflict
  $ hg debugrebuildstate
  $ hg st

Test fold with wc parent is not the head of the folded revision

  $ hg up 4
  0 files updated, 0 files merged, 2 files removed, 0 files unresolved
  $ hg fold --rev 4::11 --user victor
  3 changesets folded
  2 files updated, 0 files merged, 0 files removed, 0 files unresolved
  $ glog
  @  12:d26d339c513f@default(draft) add 4
  |
  | o  1:73d38bb17fd7@default(draft) add 1
  |/
  o  0:8685c6d34325@default(draft) add 0
  
  $ hg log --template '{rev}: {author}\n'
  12: victor
  1: test
  0: test
  $ hg log -r 12 --template '{desc}\n'
  add 4
  
  
  add 3
  
  
  add 1
  
  
  conflict
  $ hg debugrebuildstate
  $ hg st

Test olog

  $ hg olog
  4	: add 4 - test
  5	: add 3 - test
  11	: add 1 - test


Test evolving renames

  $ hg up null
  0 files updated, 0 files merged, 4 files removed, 0 files unresolved
  $ echo a > a
  $ hg ci -Am a
  adding a
  created new head
  $ echo b > b
  $ hg ci -Am b
  adding b
  $ hg mv a c
  $ hg ci -m c
  $ hg kill .^
  1 changesets pruned
  1 new unstable changesets
  $ hg stab --any
  move:[15] c
  atop:[13] a
  $ hg st -C --change=tip
  A c
    a
  R a
