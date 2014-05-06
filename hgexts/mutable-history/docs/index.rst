.. Copyright 2011 Pierre-Yves David <pierre-yves.david@ens-lyon.org>
..                Logilab SA        <contact@logilab.fr>

========================================
Changeset Evolution Experimentation
========================================


This is the online documentation of the `evolve extension`_. An experimental
extension that drive the implementation of the `changeset evolution concept`_ for
Mercurial.

.. _`evolve extension`: http://mercurial.selenic.com/wiki/EvolveExtension
.. _`changeset evolution concept`: http://mercurial.selenic.com/wiki/ChangesetEvolution

Here are various materials on planned improvement to Mercurial regarding
rewriting history.

First, read about what challenges arise while rewriting history and how we plan to
solve them once and for all.

.. toctree::
   :maxdepth: 2

   instability

The effort is split in two parts:

 * The **obsolescence marker** concept aims to provide an alternative to ``strip``
   to get rid of changesets. This concept has been partially implemented since
   Mercurial 2.3.

 * The **evolve** Mercurial extension rewrites history using obsolete
   *marker* under the hood.

The first and most important step is by far the **obsolescence marker**. However
most users will never be directly exposed to the concept. For this reason
this manual starts with changeset evolution.

Evolve: A robust alternative to MQ
====================================

Evolve is an experimental history rewriting extension that uses obsolete
markers. It is inspired by MQ and pbranch but has multiple advantages over
them:

* Focus on your current work.

    You can focus your work on a single changeset and take care of adapting
    descendent changesets later.

* Handle **non-linear history with branches and merges**

* Rely internally on Mercurial's **robust merge** mechanism.

  Simple conflicts are handled by real merge tools using the appropriate ancestor.
  Conflicts are much rarer and much more user friendly.

*  Mutable history **fully available all the time**.

  Always use 'hg update' and forget about (un)applying patches to access the
  mutable part of your history.


* Use only **plain changesets** and forget about patches. Evolve will create and
  exchange real changesets. Mutable history can be used in all usual operations:
  pull, push, log, diff, etc.

* Allow **sharing and collaboration** mutable history without fear of duplicates
  (thanks to obsolete marker).

* Cover all MQ usage but guard.

.. warning:: The evolve extension and obsolete markers are at an experimental
             stage. While using obsolete you willl likely be exposed to complex
             implications of the **obsolete marker** concept. I do not recommend
             non-power users to test this at this stage.

             While numbered 1.0.0, the command line API of this version should
             **not** be regarded as *stable*: command behavior, name and
             options may change in future releases or once integrated into
             Mercurial. It is still an immature extension; a lot of
             features are still missing but there is low risk of
             repository corruption.

             Production-ready version should hide such details from normal users.

The evolve extension requires Mercurial 2.5 (older versions supports down to 2.2)

To enable the evolve extension use::

    $ hg clone https://bitbucket.org/marmoute/mutable-history -u stable
    $ echo '[extensions]\nevolve=$PWD/mutable-history/hgext/evolve.py' >> ~/.hgrc

You will probably want to use hgview_ to visualize obsolescence. Version 1.7.1
or later is required.

.. _hgview: http://www.logilab.org/project/hgview/


 ---

For more information see the documents below:

.. toctree::
   :maxdepth: 1

   tutorials/tutorial
   evolve-good-practice
   evolve-faq
   from-mq
   evolve-collaboration
   qsync

Smart changeset deletion: Obsolete Marker
==========================================

The obsolete marker is a powerful concept that allows Mercurial to safely handle
history rewriting operations. It is a new type of relation between Mercurial
changesets that tracks the result of history rewriting operations.

This concept is simple to define and provides a very solid base for:

- very fast history rewriting operations

- auditable and reversible history rewriting process

- clean final history

- share and collaborate on mutable parts of the history

- gracefully handle history rewriting conflicts

- allow various history rewriting UI to collaborate with a underlying common API

 ---

For more information, see the documents below

.. toctree::
   :maxdepth: 1

   obs-concept
   obs-terms
   obs-implementation


Known limitations and bugs
=================================

Here is a list of known issues that will be fixed later:


* You need to provide to `graft --continue -O` if you started you
  graft using `-O`.

  you to manually specify target all the time.

* Trying to exchange obsolete marker with a static http repo will crash.

* Extinct changesets are hidden using the *hidden* feature of mercurial only
  supported by a few commands.

  Only ``hg log``, ``hgview`` and `hg glog` support it. Neither ``hg heads`` nor other visual viewers do.

* hg heads shows extinct changesets.
