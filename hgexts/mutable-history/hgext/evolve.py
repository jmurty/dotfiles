# Copyright 2011 Peter Arrenbrecht <peter.arrenbrecht@gmail.com>
#                Logilab SA        <contact@logilab.fr>
#                Pierre-Yves David <pierre-yves.david@ens-lyon.org>
#                Patrick Mezard <patrick@mezard.eu>
#
# This software may be used and distributed according to the terms of the
# GNU General Public License version 2 or any later version.

'''extends Mercurial feature related to Changeset Evolution

This extension provides several commands to mutate history and deal with
issues it may raise.

It also:

    - enables the "Changeset Obsolescence" feature of mercurial,
    - alters core commands and extensions that rewrite history to use
      this feature,
    - improves some aspect of the early implementation in 2.3
'''

testedwith = '2.7 2.7.1 2.7.2 2.8 2.8.1 2.8.2 2.9 2.9.1 2.9.2 3.0'
buglink = 'https://bitbucket.org/marmoute/mutable-history/issues'

import sys
import random

import mercurial
from mercurial import util

try:
    from mercurial import obsolete
    if not obsolete._enabled:
        obsolete._enabled = True
    from mercurial import bookmarks
    bookmarks.bmstore
except (ImportError, AttributeError):
    raise util.Abort('Your Mercurial is too old for this version of Evolve',
                     hint='requires version >> 2.4.x')



from mercurial import bookmarks
from mercurial import cmdutil
from mercurial import commands
from mercurial import context
from mercurial import copies
from mercurial import error
from mercurial import extensions
from mercurial import hg
from mercurial import lock as lockmod
from mercurial import merge
from mercurial import node
from mercurial import phases
from mercurial import revset
from mercurial import scmutil
from mercurial import templatekw
from mercurial.i18n import _
from mercurial.commands import walkopts, commitopts, commitopts2
from mercurial.node import nullid



# This extension contains the following code
#
# - Extension Helper code
# - Obsolescence cache
# - ...
# - Older format compat



#####################################################################
### Extension helper                                              ###
#####################################################################

class exthelper(object):
    """Helper for modular extension setup

    A single helper should be instanciated for each extension. Helper
    methods are then used as decorator for various purpose.

    All decorators return the original function and may be chained.
    """

    def __init__(self):
        self._uicallables = []
        self._extcallables = []
        self._repocallables = []
        self._revsetsymbols = []
        self._templatekws = []
        self._commandwrappers = []
        self._extcommandwrappers = []
        self._functionwrappers = []
        self._duckpunchers = []

    def final_uisetup(self, ui):
        """Method to be used as the extension uisetup

        The following operations belong here:

        - Changes to ui.__class__ . The ui object that will be used to run the
          command has not yet been created. Changes made here will affect ui
          objects created after this, and in particular the ui that will be
          passed to runcommand
        - Command wraps (extensions.wrapcommand)
        - Changes that need to be visible to other extensions: because
          initialization occurs in phases (all extensions run uisetup, then all
          run extsetup), a change made here will be visible to other extensions
          during extsetup
        - Monkeypatch or wrap function (extensions.wrapfunction) of dispatch
          module members
        - Setup of pre-* and post-* hooks
        - pushkey setup
        """
        for cont, funcname, func in self._duckpunchers:
            setattr(cont, funcname, func)
        for command, wrapper in self._commandwrappers:
            extensions.wrapcommand(commands.table, command, wrapper)
        for cont, funcname, wrapper in self._functionwrappers:
            extensions.wrapfunction(cont, funcname, wrapper)
        for c in self._uicallables:
            c(ui)

    def final_extsetup(self, ui):
        """Method to be used as a the extension extsetup

        The following operations belong here:

        - Changes depending on the status of other extensions. (if
          extensions.find('mq'))
        - Add a global option to all commands
        - Register revset functions
        """
        knownexts = {}
        for name, symbol in self._revsetsymbols:
            revset.symbols[name] = symbol
        for name, kw in self._templatekws:
            templatekw.keywords[name] = kw
        for ext, command, wrapper in self._extcommandwrappers:
            if ext not in knownexts:
                e = extensions.find(ext)
                if e is None:
                    raise util.Abort('extension %s not found' % ext)
                knownexts[ext] = e.cmdtable
            extensions.wrapcommand(knownexts[ext], commands, wrapper)
        for c in self._extcallables:
            c(ui)

    def final_reposetup(self, ui, repo):
        """Method to be used as a the extension reposetup

        The following operations belong here:

        - All hooks but pre-* and post-*
        - Modify configuration variables
        - Changes to repo.__class__, repo.dirstate.__class__
        """
        for c in self._repocallables:
            c(ui, repo)

    def uisetup(self, call):
        """Decorated function will be executed during uisetup

        example::

            @eh.uisetup
            def setupbabar(ui):
                print 'this is uisetup!'
        """
        self._uicallables.append(call)
        return call

    def extsetup(self, call):
        """Decorated function will be executed during extsetup

        example::

            @eh.extsetup
            def setupcelestine(ui):
                print 'this is extsetup!'
        """
        self._extcallables.append(call)
        return call

    def reposetup(self, call):
        """Decorated function will be executed during reposetup

        example::

            @eh.reposetup
            def setupzephir(ui, repo):
                print 'this is reposetup!'
        """
        self._repocallables.append(call)
        return call

    def revset(self, symbolname):
        """Decorated function is a revset symbol

        The name of the symbol must be given as the decorator argument.
        The symbol is added during `extsetup`.

        example::

            @eh.revset('hidden')
            def revsetbabar(repo, subset, x):
                args = revset.getargs(x, 0, 0, 'babar accept no argument')
                return [r for r in subset if 'babar' in repo[r].description()]
        """
        def dec(symbol):
            self._revsetsymbols.append((symbolname, symbol))
            return symbol
        return dec


    def templatekw(self, keywordname):
        """Decorated function is a revset keyword

        The name of the keyword must be given as the decorator argument.
        The symbol is added during `extsetup`.

        example::

            @eh.templatekw('babar')
            def kwbabar(ctx):
                return 'babar'
        """
        def dec(keyword):
            self._templatekws.append((keywordname, keyword))
            return keyword
        return dec

    def wrapcommand(self, command, extension=None):
        """Decorated function is a command wrapper

        The name of the command must be given as the decorator argument.
        The wrapping is installed during `uisetup`.

        If the second option `extension` argument is provided, the wrapping
        will be applied in the extension commandtable. This argument must be a
        string that will be searched using `extension.find` if not found and
        Abort error is raised. If the wrapping applies to an extension, it is
        installed during `extsetup`

        example::

            @eh.wrapcommand('summary')
            def wrapsummary(orig, ui, repo, *args, **kwargs):
                ui.note('Barry!')
                return orig(ui, repo, *args, **kwargs)

        """
        def dec(wrapper):
            if extension is None:
                self._commandwrappers.append((command, wrapper))
            else:
                self._extcommandwrappers.append((extension, command, wrapper))
            return wrapper
        return dec

    def wrapfunction(self, container, funcname):
        """Decorated function is a function wrapper

        This function takes two arguments, the container and the name of the
        function to wrap. The wrapping is performed during `uisetup`.
        (there is no extension support)

        example::

            @eh.function(discovery, 'checkheads')
            def wrapfunction(orig, *args, **kwargs):
                ui.note('His head smashed in and his heart cut out')
                return orig(*args, **kwargs)
        """
        def dec(wrapper):
            self._functionwrappers.append((container, funcname, wrapper))
            return wrapper
        return dec

    def addattr(self, container, funcname):
        """Decorated function is to be added to the container

        This function takes two arguments, the container and the name of the
        function to wrap. The wrapping is performed during `uisetup`.

        example::

            @eh.function(context.changectx, 'babar')
            def babar(ctx):
                return 'babar' in ctx.description
        """
        def dec(func):
            self._duckpunchers.append((container, funcname, func))
            return func
        return dec

eh = exthelper()
uisetup = eh.final_uisetup
extsetup = eh.final_extsetup
reposetup = eh.final_reposetup

#####################################################################
### Critical fix                                                  ###
#####################################################################

@eh.wrapfunction(mercurial.obsolete, '_readmarkers')
def safereadmarkers(orig, data):
    """safe maker wrapper to remove nullid succesors

    Nullid successors was created by older version of evolve.
    """
    nb = 0
    for marker in orig(data):
        if nullid in marker[1]:
            marker = (marker[0],
                      tuple(s for s in marker[1] if s != nullid),
                      marker[2],
                      marker[3])
            nb += 1
        yield marker
    if nb:
        e = sys.stderr
        print >> e, 'repo contains %i invalid obsolescence markers' % nb

getrevs = obsolete.getrevs

#####################################################################
### Additional Utilities                                          ###
#####################################################################

# This section contains a lot of small utility function and method

# - Function to create markers
# - useful alias pstatus and pdiff (should probably go in evolve)
# - "troubles" method on changectx
# - function to travel throught the obsolescence graph
# - function to find useful changeset to stabilize

createmarkers = obsolete.createmarkers


### Useful alias

@eh.uisetup
def _installalias(ui):
    if ui.config('alias', 'pstatus', None) is None:
        ui.setconfig('alias', 'pstatus', 'status --rev .^')
    if ui.config('alias', 'pdiff', None) is None:
        ui.setconfig('alias', 'pdiff', 'diff --rev .^')
    if ui.config('alias', 'olog', None) is None:
        ui.setconfig('alias', 'olog', "log -r 'precursors(.)' --hidden")
    if ui.config('alias', 'odiff', None) is None:
        ui.setconfig('alias', 'odiff', "diff --hidden --rev 'limit(precursors(.),1)' --rev .")
    if ui.config('alias', 'grab', None) is None:
        ui.setconfig('alias', 'grab', "! $HG rebase --dest . --rev $@ && $HG up tip")


### Troubled revset symbol

@eh.revset('troubled')
def revsettroubled(repo, subset, x):
    """``troubled()``
    Changesets with troubles.
    """
    _ = revset.getargs(x, 0, 0, 'troubled takes no arguments')
    return repo.revs('%ld and (unstable() + bumped() + divergent())',
                     subset)


### Obsolescence graph

# XXX SOME MAJOR CLEAN UP TO DO HERE XXX

def _precursors(repo, s):
    """Precursor of a changeset"""
    cs = set()
    nm = repo.changelog.nodemap
    markerbysubj = repo.obsstore.precursors
    for r in s:
        for p in markerbysubj.get(repo[r].node(), ()):
            pr = nm.get(p[0])
            if pr is not None:
                cs.add(pr)
    return cs

def _allprecursors(repo, s):  # XXX we need a better naming
    """transitive precursors of a subset"""
    toproceed = [repo[r].node() for r in s]
    seen = set()
    allsubjects = repo.obsstore.precursors
    while toproceed:
        nc = toproceed.pop()
        for mark in allsubjects.get(nc, ()):
            np = mark[0]
            if np not in seen:
                seen.add(np)
                toproceed.append(np)
    nm = repo.changelog.nodemap
    cs = set()
    for p in seen:
        pr = nm.get(p)
        if pr is not None:
            cs.add(pr)
    return cs

def _successors(repo, s):
    """Successors of a changeset"""
    cs = set()
    nm = repo.changelog.nodemap
    markerbyobj = repo.obsstore.successors
    for r in s:
        for p in markerbyobj.get(repo[r].node(), ()):
            for sub in p[1]:
                sr = nm.get(sub)
                if sr is not None:
                    cs.add(sr)
    return cs

def _allsuccessors(repo, s, haltonflags=0):  # XXX we need a better naming
    """transitive successors of a subset

    haltonflags allows to provide flags which prevent the evaluation of a
    marker.  """
    toproceed = [repo[r].node() for r in s]
    seen = set()
    allobjects = repo.obsstore.successors
    while toproceed:
        nc = toproceed.pop()
        for mark in allobjects.get(nc, ()):
            if mark[2] & haltonflags:
                continue
            for sub in mark[1]:
                if sub == nullid:
                    continue # should not be here!
                if sub not in seen:
                    seen.add(sub)
                    toproceed.append(sub)
    nm = repo.changelog.nodemap
    cs = set()
    for s in seen:
        sr = nm.get(s)
        if sr is not None:
            cs.add(sr)
    return cs




#####################################################################
### Extending revset and template                                 ###
#####################################################################

# this section add several useful revset symbol not yet in core.
# they are subject to changes


### XXX I'm not sure this revset is useful
@eh.revset('suspended')
def revsetsuspended(repo, subset, x):
    """``suspended()``
    Obsolete changesets with non-obsolete descendants.
    """
    args = revset.getargs(x, 0, 0, 'suspended takes no arguments')
    suspended = getrevs(repo, 'suspended')
    return [r for r in subset if r in suspended]


@eh.revset('precursors')
def revsetprecursors(repo, subset, x):
    """``precursors(set)``
    Immediate precursors of changesets in set.
    """
    s = revset.getset(repo, range(len(repo)), x)
    cs = _precursors(repo, s)
    return [r for r in subset if r in cs]


@eh.revset('allprecursors')
def revsetallprecursors(repo, subset, x):
    """``allprecursors(set)``
    Transitive precursors of changesets in set.
    """
    s = revset.getset(repo, range(len(repo)), x)
    cs = _allprecursors(repo, s)
    return [r for r in subset if r in cs]


@eh.revset('successors')
def revsetsuccessors(repo, subset, x):
    """``successors(set)``
    Immediate successors of changesets in set.
    """
    s = revset.getset(repo, range(len(repo)), x)
    cs = _successors(repo, s)
    return [r for r in subset if r in cs]

@eh.revset('allsuccessors')
def revsetallsuccessors(repo, subset, x):
    """``allsuccessors(set)``
    Transitive successors of changesets in set.
    """
    s = revset.getset(repo, range(len(repo)), x)
    cs = _allsuccessors(repo, s)
    return [r for r in subset if r in cs]

### template keywords
# XXX it does not handle troubles well :-/

@eh.templatekw('obsolete')
def obsoletekw(repo, ctx, templ, **args):
    """:obsolete: String. The obsolescence level of the node, could be
    ``stable``, ``unstable``, ``suspended`` or ``extinct``.
    """
    rev = ctx.rev()
    if ctx.obsolete():
        if ctx.extinct():
            return 'extinct'
        else:
            return 'suspended'
    elif ctx.unstable():
        return 'unstable'
    return 'stable'

#####################################################################
### Various trouble warning                                       ###
#####################################################################

# This section take care of issue warning to the user when troubles appear

@eh.wrapcommand("update")
@eh.wrapcommand("parents")
@eh.wrapcommand("pull")
def wrapmayobsoletewc(origfn, ui, repo, *args, **opts):
    """Warn that the working directory parent is an obsolete changeset"""
    res = origfn(ui, repo, *args, **opts)
    if repo['.'].obsolete():
        ui.warn(_('working directory parent is obsolete!\n'))
    return res

# XXX this could wrap transaction code
# XXX (but this is a bit a layer violation)
@eh.wrapcommand("commit")
@eh.wrapcommand("import")
@eh.wrapcommand("push")
@eh.wrapcommand("pull")
@eh.wrapcommand("graft")
@eh.wrapcommand("phase")
@eh.wrapcommand("unbundle")
def warnobserrors(orig, ui, repo, *args, **kwargs):
    """display warning is the command resulted in more instable changeset"""
    # part of the troubled stuff may be filtered (stash ?)
    # This needs a better implementation but will probably wait for core.
    filtered = repo.changelog.filteredrevs
    priorunstables = len(set(getrevs(repo, 'unstable')) - filtered)
    priorbumpeds = len(set(getrevs(repo, 'bumped')) - filtered)
    priordivergents = len(set(getrevs(repo, 'divergent')) - filtered)
    ret = orig(ui, repo, *args, **kwargs)
    # workaround phase stupidity
    #phases._filterunknown(ui, repo.changelog, repo._phasecache.phaseroots)
    filtered = repo.changelog.filteredrevs
    newunstables = len(set(getrevs(repo, 'unstable')) - filtered) - priorunstables
    newbumpeds = len(set(getrevs(repo, 'bumped')) - filtered) - priorbumpeds
    newdivergents = len(set(getrevs(repo, 'divergent')) - filtered) - priordivergents
    if newunstables > 0:
        ui.warn(_('%i new unstable changesets\n') % newunstables)
    if newbumpeds > 0:
        ui.warn(_('%i new bumped changesets\n') % newbumpeds)
    if newdivergents > 0:
        ui.warn(_('%i new divergent changesets\n') % newdivergents)
    return ret

@eh.reposetup
def _repostabilizesetup(ui, repo):
    """Add a hint for "hg evolve" when troubles make push fails
    """
    if not repo.local():
        return

    class evolvingrepo(repo.__class__):
        def push(self, remote, *args, **opts):
            """wrapper around pull that pull obsolete relation"""
            try:
                result = super(evolvingrepo, self).push(remote, *args, **opts)
            except util.Abort, ex:
                hint = _("use 'hg evolve' to get a stable history "
                         "or --force to ignore warnings")
                if (len(ex.args) >= 1
                    and ex.args[0].startswith('push includes ')
                    and ex.hint is None):
                    ex.hint = hint
                raise
            return result
    repo.__class__ = evolvingrepo

def summaryhook(ui, repo):
    def write(fmt, count):
        s = fmt % count
        if count:
            ui.write(s)
        else:
            ui.note(s)

    nbunstable = len(getrevs(repo, 'unstable'))
    nbbumped = len(getrevs(repo, 'bumped'))
    nbdivergent = len(getrevs(repo, 'divergent'))
    write('unstable: %i changesets\n', nbunstable)
    write('bumped: %i changesets\n', nbbumped)
    write('divergent: %i changesets\n', nbdivergent)

@eh.extsetup
def obssummarysetup(ui):
    cmdutil.summaryhooks.add('evolve', summaryhook)


#####################################################################
### Core Other extension compat                                   ###
#####################################################################


@eh.extsetup
def _rebasewrapping(ui):
    # warning about more obsolete
    try:
        rebase = extensions.find('rebase')
        if rebase:
            extensions.wrapcommand(rebase.cmdtable, 'rebase', warnobserrors)
    except KeyError:
        pass  # rebase not found
    try:
        histedit = extensions.find('histedit')
        if histedit:
            extensions.wrapcommand(histedit.cmdtable, 'histedit', warnobserrors)
    except KeyError:
        pass  # rebase not found


#####################################################################
### Old Evolve extension content                                  ###
#####################################################################

# XXX need clean up and proper sorting in other section

### util function
#############################

### changeset rewriting logic
#############################

def rewrite(repo, old, updates, head, newbases, commitopts):
    """Return (nodeid, created) where nodeid is the identifier of the
    changeset generated by the rewrite process, and created is True if
    nodeid was actually created. If created is False, nodeid
    references a changeset existing before the rewrite call.
    """
    if len(old.parents()) > 1: #XXX remove this unecessary limitation.
        raise error.Abort(_('cannot amend merge changesets'))
    base = old.p1()
    updatebookmarks = _bookmarksupdater(repo, old.node())

    wlock = repo.wlock()
    try:

        # commit a new version of the old changeset, including the update
        # collect all files which might be affected
        files = set(old.files())
        for u in updates:
            files.update(u.files())

        # Recompute copies (avoid recording a -> b -> a)
        copied = copies.pathcopies(base, head)


        # prune files which were reverted by the updates
        def samefile(f):
            if f in head.manifest():
                a = head.filectx(f)
                if f in base.manifest():
                    b = base.filectx(f)
                    return (a.data() == b.data()
                            and a.flags() == b.flags())
                else:
                    return False
            else:
                return f not in base.manifest()
        files = [f for f in files if not samefile(f)]
        # commit version of these files as defined by head
        headmf = head.manifest()
        def filectxfn(repo, ctx, path):
            if path in headmf:
                fctx = head[path]
                flags = fctx.flags()
                mctx = context.memfilectx(fctx.path(), fctx.data(),
                                          islink='l' in flags,
                                          isexec='x' in flags,
                                          copied=copied.get(path))
                return mctx
            raise IOError()
        if commitopts.get('message') and commitopts.get('logfile'):
            raise util.Abort(_('options --message and --logfile are mutually'
                               ' exclusive'))
        if commitopts.get('logfile'):
            message= open(commitopts['logfile']).read()
        elif commitopts.get('message'):
            message = commitopts['message']
        else:
            message = old.description()

        user = commitopts.get('user') or old.user()
        date = commitopts.get('date') or None # old.date()
        extra = dict(commitopts.get('extra', {}))
        extra['branch'] = head.branch()

        new = context.memctx(repo,
                             parents=newbases,
                             text=message,
                             files=files,
                             filectxfn=filectxfn,
                             user=user,
                             date=date,
                             extra=extra)

        if commitopts.get('edit'):
            new._text = cmdutil.commitforceeditor(repo, new, [])
        revcount = len(repo)
        newid = repo.commitctx(new)
        new = repo[newid]
        created = len(repo) != revcount
        updatebookmarks(newid)
    finally:
        wlock.release()

    return newid, created

class MergeFailure(util.Abort):
    pass

def relocate(repo, orig, dest):
    """rewrite <rev> on dest"""
    try:
        if orig.rev() == dest.rev():
            raise util.Abort(_('tried to relocade a node on top of itself'),
                             hint=_("This shouldn't happen. If you still "
                                    "need to move changesets, please do so "
                                    "manually with nothing to rebase - working directory parent is also destination"))

        rebase = extensions.find('rebase')
        # dummy state to trick rebase node
        if not orig.p2().rev() == node.nullrev:
            raise util.Abort(
                'no support for evolution merge changesets yet',
                hint="Redo the merge a use `hg prune` to obsolete the old one")
        destbookmarks = repo.nodebookmarks(dest.node())
        nodesrc = orig.node()
        destphase = repo[nodesrc].phase()
        wlock = lock = None
        try:
            wlock = repo.wlock()
            lock = repo.lock()
            r = rebase.rebasenode(repo, orig.node(), dest.node(),
                                  {node.nullrev: node.nullrev}, False)
            if r[-1]: #some conflict
                raise util.Abort(
                        'unresolved merge conflicts (see hg help resolve)')
            cmdutil.duplicatecopies(repo, orig.node(), dest.node())
            nodenew = rebase.concludenode(repo, orig.node(), dest.node(),
                                          node.nullid)
        except util.Abort, exc:
            class LocalMergeFailure(MergeFailure, exc.__class__):
                pass
            exc.__class__ = LocalMergeFailure
            raise
        finally:
            lockmod.release(lock, wlock)
        oldbookmarks = repo.nodebookmarks(nodesrc)
        if nodenew is not None:
            phases.retractboundary(repo, destphase, [nodenew])
            createmarkers(repo, [(repo[nodesrc], (repo[nodenew],))])
            for book in oldbookmarks:
                repo._bookmarks[book] = nodenew
        else:
            createmarkers(repo, [(repo[nodesrc], ())])
            # Behave like rebase, move bookmarks to dest
            for book in oldbookmarks:
                repo._bookmarks[book] = dest.node()
        for book in destbookmarks: # restore bookmark that rebase move
            repo._bookmarks[book] = dest.node()
        if oldbookmarks or destbookmarks:
            repo._bookmarks.write()
        return nodenew
    except util.Abort:
        # Invalidate the previous setparents
        repo.dirstate.invalidate()
        raise

def _bookmarksupdater(repo, oldid):
    """Return a callable update(newid) updating the current bookmark
    and bookmarks bound to oldid to newid.
    """
    bm = bookmarks.readcurrent(repo)
    def updatebookmarks(newid):
        dirty = False
        if bm:
            repo._bookmarks[bm] = newid
            dirty = True
        oldbookmarks = repo.nodebookmarks(oldid)
        if oldbookmarks:
            for b in oldbookmarks:
                repo._bookmarks[b] = newid
            dirty = True
        if dirty:
            repo._bookmarks.write()
    return updatebookmarks

### new command
#############################
cmdtable = {}
command = cmdutil.command(cmdtable)
metadataopts = [
    ('d', 'date', '',
     _('record the specified date in metadata'), _('DATE')),
    ('u', 'user', '',
     _('record the specified user in metadata'), _('USER')),
]


@command('^evolve|stabilize|solve',
    [('n', 'dry-run', False, 'do not perform actions, just print what would be done'),
    ('A', 'any', False, 'evolve any troubled changeset'),
    ('a', 'all', False, 'evolve all troubled changesets'),
    ('c', 'continue', False, 'continue an interrupted evolution'), ],
    _('[OPTIONS]...'))
def evolve(ui, repo, **opts):
    """Solve trouble in your repository

    - rebase unstable changesets to make them stable again,
    - create proper diffs from bumped changesets,
    - merge divergent changesets,
    - update to a successor if the working directory parent is
      obsolete

    By default, takes the first troubled changeset that looks relevant.

    (The logic is still a bit fuzzy)

    - For unstable, this means taking the first which could be rebased as a
      child of the working directory parent revision or one of its descendants
      and rebasing it.

    - For divergent, this means taking "." if applicable.

    With --any, evolve picks any troubled changeset to repair.

    The working directory is updated to the newly created revision.
    """

    contopt = opts['continue']
    anyopt = opts['any']
    allopt = opts['all']
    dryrunopt = opts['dry_run']

    if contopt:
        if anyopt:
            raise util.Abort('can not specify both "--any" and "--continue"')
        if allopt:
            raise util.Abort('can not specify both "--all" and "--continue"')
        graftcmd = commands.table['graft'][0]
        return graftcmd(ui, repo, old_obsolete=True, **{'continue': True})

    tr = _picknexttroubled(ui, repo, anyopt or allopt)
    if tr is None:
        if repo['.'].obsolete():
            displayer = cmdutil.show_changeset(ui, repo, {'template': shorttemplate})
            successors = set()

            for successorsset in obsolete.successorssets(repo, repo['.'].node()):
                for nodeid in successorsset:
                    successors.add(repo[nodeid])

            if not successors:
                ui.warn(_('parent is obsolete without successors; ' +
                          'likely killed\n'))
                return 2

            elif len(successors) > 1:
                ui.warn(_('parent is obsolete with multiple successors:\n'))

                for ctx in sorted(successors, key=lambda ctx: ctx.rev()):
                    displayer.show(ctx)

                return 2

            else:
                ctx = successors.pop()

                ui.status(_('update:'))
                if not ui.quiet:
                    displayer.show(ctx)

                if dryrunopt:
                    print 'hg update %s' % ctx.rev()
                    return 0
                else:
                    return hg.update(repo, ctx.rev())

        troubled = repo.revs('troubled()')
        if troubled:
            ui.write_err(_('nothing to evolve here\n'))
            ui.status(_('(%i troubled changesets, do you want --any ?)\n')
                      % len(troubled))
            return 2
        else:
            ui.write_err(_('no troubled changesets\n'))
            return 1

    def progresscb():
        if allopt:
            ui.progress('evolve', seen, unit='changesets', total=count)
    seen = 1
    count = allopt and _counttroubled(ui, repo) or 1

    while tr is not None:
        progresscb()
        result = _evolveany(ui, repo, tr, dryrunopt, progresscb=progresscb)
        progresscb()
        seen += 1
        if not allopt:
            return result
        progresscb()
        tr = _picknexttroubled(ui, repo, anyopt or allopt)

    if allopt:
        ui.progress('evolve', None)


def _evolveany(ui, repo, tr, dryrunopt, progresscb):
    repo = repo.unfiltered()
    tr = repo[tr.rev()]
    cmdutil.bailifchanged(repo)
    troubles = tr.troubles()
    if 'unstable' in troubles:
        return _solveunstable(ui, repo, tr, dryrunopt, progresscb)
    elif 'bumped' in troubles:
        return _solvebumped(ui, repo, tr, dryrunopt, progresscb)
    elif 'divergent' in troubles:
        repo = repo.unfiltered()
        tr = repo[tr.rev()]
        return _solvedivergent(ui, repo, tr, dryrunopt, progresscb)
    else:
        assert False  # WHAT? unknown troubles

def _counttroubled(ui, repo):
    """Count the amount of troubled changesets"""
    troubled = set()
    troubled.update(getrevs(repo, 'unstable'))
    troubled.update(getrevs(repo, 'bumped'))
    troubled.update(getrevs(repo, 'divergent'))
    return len(troubled)

def _picknexttroubled(ui, repo, pickany=False, progresscb=None):
    """Pick a the next trouble changeset to solve"""
    if progresscb: progresscb()
    tr = _stabilizableunstable(repo, repo['.'])
    if tr is None:
        wdp = repo['.']
        if 'divergent' in wdp.troubles():
            tr = wdp
    if tr is None and pickany:
        troubled = list(repo.set('unstable()'))
        if not troubled:
            troubled = list(repo.set('bumped()'))
        if not troubled:
            troubled = list(repo.set('divergent()'))
        if troubled:
            tr = troubled[0]

    return tr

def _stabilizableunstable(repo, pctx):
    """Return a changectx for an unstable changeset which can be
    stabilized on top of pctx or one of its descendants. None if none
    can be found.
    """
    def selfanddescendants(repo, pctx):
        yield pctx
        for prec in repo.set('allprecursors(%d)', pctx):
            yield prec
        for ctx in pctx.descendants():
            yield ctx
            for prec in repo.set('allprecursors(%d)', ctx):
                yield prec

    # Look for an unstable which can be stabilized as a child of
    # node. The unstable must be a child of one of node predecessors.
    for ctx in selfanddescendants(repo, pctx):
        for child in ctx.children():
            if child.unstable():
                return child
    return None

def _solveunstable(ui, repo, orig, dryrun=False, progresscb=None):
    """Stabilize a unstable changeset"""
    obs = orig.parents()[0]
    if not obs.obsolete():
        print obs.rev(), orig.parents()
        print orig.rev()
        obs = orig.parents()[1]
    assert obs.obsolete()
    newer = obsolete.successorssets(repo, obs.node())
    # search of a parent which is not killed
    while not newer or newer == [()]:
        ui.debug("stabilize target %s is plain dead,"
                 " trying to stabilize on its parent")
        obs = obs.parents()[0]
        newer = obsolete.successorssets(repo, obs.node())
    if len(newer) > 1:
        raise util.Abort(_("conflict rewriting. can't choose destination\n"))
    targets = newer[0]
    assert targets
    if len(targets) > 1:
        raise util.Abort(_("does not handle split parents yet\n"))
        return 2
    target = targets[0]
    displayer = cmdutil.show_changeset(ui, repo, {'template': shorttemplate})
    target = repo[target]
    repo.ui.status(_('move:'))
    if not ui.quiet:
        displayer.show(orig)
    repo.ui.status(_('atop:'))
    if not ui.quiet:
        displayer.show(target)
    if progresscb: progresscb()
    todo = 'hg rebase -r %s -d %s\n' % (orig, target)
    if dryrun:
        repo.ui.write(todo)
    else:
        repo.ui.note(todo)
        if progresscb: progresscb()
        lock = repo.lock()
        try:
            relocate(repo, orig, target)
        except MergeFailure:
            repo.opener.write('graftstate', orig.hex() + '\n')
            repo.ui.write_err(_('evolve failed!\n'))
            repo.ui.write_err(_('fix conflict and run "hg evolve --continue"\n'))
            raise
        finally:
            lock.release()

def _solvebumped(ui, repo, bumped, dryrun=False, progresscb=None):
    """Stabilize a bumped changeset"""
    # For now we deny bumped merge
    if len(bumped.parents()) > 1:
        raise util.Abort('late comer stabilization is confused by bumped'
                         ' %s being a merge' % bumped)
    prec = repo.set('last(allprecursors(%d) and public())', bumped).next()
    # For now we deny target merge
    if len(prec.parents()) > 1:
        raise util.Abort('late comer evolution is confused by precursors'
                         ' %s being a merge' % prec)

    displayer = cmdutil.show_changeset(ui, repo, {'template': shorttemplate})
    repo.ui.status(_('recreate:'))
    if not ui.quiet:
        displayer.show(bumped)
    repo.ui.status(_('atop:'))
    if not ui.quiet:
        displayer.show(prec)
    if dryrun:
        todo = 'hg rebase --rev %s --dest %s;\n' % (bumped, prec.p1())
        repo.ui.write(todo)
        repo.ui.write('hg update %s;\n' % prec)
        repo.ui.write('hg revert --all --rev %s;\n' % bumped)
        repo.ui.write('hg commit --msg "bumped update to %s"')
        return 0
    if progresscb: progresscb()
    wlock = repo.wlock()
    try:
        newid = tmpctx = None
        tmpctx = bumped
        lock = repo.lock()
        try:
            bmupdate = _bookmarksupdater(repo, bumped.node())
            # Basic check for common parent. Far too complicated and fragile
            tr = repo.transaction('bumped-stabilize')
            try:
                if not list(repo.set('parents(%d) and parents(%d)', bumped, prec)):
                    # Need to rebase the changeset at the right place
                    repo.ui.status(_('rebasing to destination parent: %s\n') % prec.p1())
                    try:
                        tmpid = relocate(repo, bumped, prec.p1())
                        if tmpid is not None:
                            tmpctx = repo[tmpid]
                            createmarkers(repo, [(bumped, (tmpctx,))])
                    except MergeFailure:
                        repo.opener.write('graftstate', bumped.hex() + '\n')
                        repo.ui.write_err(_('evolution failed!\n'))
                        repo.ui.write_err(_('fix conflict and run "hg evolve --continue"\n'))
                        raise
                # Create the new commit context
                repo.ui.status(_('computing new diff\n'))
                files = set()
                copied = copies.pathcopies(prec, bumped)
                precmanifest = prec.manifest()
                for key, val in bumped.manifest().iteritems():
                    if precmanifest.pop(key, None) != val:
                        files.add(key)
                files.update(precmanifest)  # add missing files
                # commit it
                if files: # something to commit!
                    def filectxfn(repo, ctx, path):
                        if path in bumped:
                            fctx = bumped[path]
                            flags = fctx.flags()
                            mctx = context.memfilectx(fctx.path(), fctx.data(),
                                                      islink='l' in flags,
                                                      isexec='x' in flags,
                                                      copied=copied.get(path))
                            return mctx
                        raise IOError()
                    text = 'bumped update to %s:\n\n' % prec
                    text += bumped.description()

                    new = context.memctx(repo,
                                         parents=[prec.node(), node.nullid],
                                         text=text,
                                         files=files,
                                         filectxfn=filectxfn,
                                         user=bumped.user(),
                                         date=bumped.date(),
                                         extra=bumped.extra())

                    newid = repo.commitctx(new)
                if newid is None:
                    createmarkers(repo, [(tmpctx, ())])
                    newid = prec.node()
                else:
                    phases.retractboundary(repo, bumped.phase(), [newid])
                    createmarkers(repo, [(tmpctx, (repo[newid],))],
                                           flag=obsolete.bumpedfix)
                bmupdate(newid)
                tr.close()
                repo.ui.status(_('commited as %s\n') % node.short(newid))
            finally:
                tr.release()
        finally:
            lock.release()
        # reroute the working copy parent to the new changeset
        repo.dirstate.setparents(newid, node.nullid)
    finally:
        wlock.release()

def _solvedivergent(ui, repo, divergent, dryrun=False, progresscb=None):
    base, others = divergentdata(divergent)
    if len(others) > 1:
        othersstr = "[%s]" % (','.join([str(i) for i in others]))
        hint = ("changeset %d is divergent with a changeset that got splitted "
                "| into multiple ones:\n[%s]\n"
                "| This is not handled by automatic evolution yet\n"
                "| You have to fallback to manual handling with commands as:\n"
                "| - hg touch -D\n"
                "| - hg prune\n"
                "| \n"
                "| You should contact your local evolution Guru for help.\n"
                % (divergent, othersstr))
        raise util.Abort("We do not handle divergence with split yet",
                         hint='')
    other = others[0]
    if divergent.phase() <= phases.public:
        raise util.Abort("We can't resolve this conflict from the public side",
                         hint="%s is public, try from %s" % (divergent, other))
    if len(other.parents()) > 1:
        raise util.Abort("divergent changeset can't be a merge (yet)",
                          hint="You have to fallback to solving this by hand...\n"
                               "| This probably mean to redo the merge and use "
                               "| `hg prune` to kill older version.")
    if other.p1() not in divergent.parents():
        raise util.Abort("parents are not common (not handled yet)",
                         hint="| %(d)s, %(o)s are not based on the same changeset."
                              "| With the current state of its implementation, "
                              "| evolve does not work in that case.\n"
                              "| rebase one of them next to the other and run "
                              "| this command again.\n"
                              "| - either: hg rebase -dest 'p1(%(d)s)' -r %(o)s"
                              "| - or:     hg rebase -dest 'p1(%(d)s)' -r %(o)s"
                              % {'d': divergent, 'o': other})

    displayer = cmdutil.show_changeset(ui, repo, {'template': shorttemplate})
    ui.status(_('merge:'))
    if not ui.quiet:
        displayer.show(divergent)
    ui.status(_('with: '))
    if not ui.quiet:
        displayer.show(other)
    ui.status(_('base: '))
    if not ui.quiet:
        displayer.show(base)
    if dryrun:
        ui.write('hg update -c %s &&\n' % divergent)
        ui.write('hg merge %s &&\n' % other)
        ui.write('hg commit -m "auto merge resolving conflict between '
                 '%s and %s"&&\n' % (divergent, other))
        ui.write('hg up -C %s &&\n' % base)
        ui.write('hg revert --all --rev tip &&\n')
        ui.write('hg commit -m "`hg log -r %s --template={desc}`";\n'
                 % divergent)
        return
    wlock = lock = None
    try:
        wlock = repo.wlock()
        lock = repo.lock()
        if divergent not in repo[None].parents():
            repo.ui.status(_('updating to "local" conflict\n'))
            hg.update(repo, divergent.rev())
        repo.ui.note(_('merging divergent changeset\n'))
        if progresscb: progresscb()
        stats = merge.update(repo,
                             other.node(),
                             branchmerge=True,
                             force=False,
                             partial=None,
                             ancestor=base.node(),
                             mergeancestor=True)
        hg._showstats(repo, stats)
        if stats[3]:
            repo.ui.status(_("use 'hg resolve' to retry unresolved file merges "
                             "or 'hg update -C .' to abandon\n"))
        if stats[3] > 0:
            raise util.Abort('Merge conflict between several amendments, and this is not yet automated',
                hint="""/!\ You can try:
/!\ * manual merge + resolve => new cset X
/!\ * hg up to the parent of the amended changeset (which are named W and Z)
/!\ * hg revert --all -r X
/!\ * hg ci -m "same message as the amended changeset" => new cset Y
/!\ * hg kill -n Y W Z
""")
        if progresscb: progresscb()
        tr = repo.transaction('stabilize-divergent')
        try:
            repo.dirstate.setparents(divergent.node(), node.nullid)
            oldlen = len(repo)
            amend(ui, repo, message='', logfile='')
            if oldlen == len(repo):
                new = divergent
                # no changes
            else:
                new = repo['.']
            createmarkers(repo, [(other, (new,))])
            phases.retractboundary(repo, other.phase(), [new.node()])
            tr.close()
        finally:
            tr.release()
    finally:
        lockmod.release(lock, wlock)


def divergentdata(ctx):
    """return base, other part of a conflict

    This only return the first one.

    XXX this woobly function won't survive XXX
    """
    for base in ctx._repo.set('reverse(precursors(%d))', ctx):
        newer = obsolete.successorssets(ctx._repo, base.node())
        # drop filter and solution including the original ctx
        newer = [n for n in newer if n and ctx.node() not in n]
        if newer:
            return base, tuple(ctx._repo[o] for o in newer[0])
    raise util.Abort('base of divergent changeset not found',
                     hint='this case is not yet handled')



shorttemplate = '[{rev}] {desc|firstline}\n'

@command('^gdown|previous',
         [],
         '')
def cmdprevious(ui, repo):
    """update to parent and display summary lines"""
    wkctx = repo[None]
    wparents = wkctx.parents()
    if len(wparents) != 1:
        raise util.Abort('merge in progress')

    parents = wparents[0].parents()
    displayer = cmdutil.show_changeset(ui, repo, {'template': shorttemplate})
    if len(parents) == 1:
        p = parents[0]
        bm = bookmarks.readcurrent(repo)
        shouldmove = bm is not None and bookmarks.iscurrent(repo, bm)
        ret = hg.update(repo, p.rev())
        if not ret and shouldmove:
            repo._bookmarks[bm] = p.node()
            repo._bookmarks.write()
        displayer.show(p)
        return 0
    else:
        for p in parents:
            displayer.show(p)
        ui.warn(_('multiple parents, explicitly update to one\n'))
        return 1

@command('^gup|next',
         [],
         '')
def cmdnext(ui, repo):
    """update to child and display summary lines"""
    wkctx = repo[None]
    wparents = wkctx.parents()
    if len(wparents) != 1:
        raise util.Abort('merge in progress')

    children = [ctx for ctx in wparents[0].children() if not ctx.obsolete()]
    displayer = cmdutil.show_changeset(ui, repo, {'template': shorttemplate})
    if not children:
        ui.warn(_('no non-obsolete children\n'))
        return 1
    if len(children) == 1:
        c = children[0]
        bm = bookmarks.readcurrent(repo)
        shouldmove = bm is not None and bookmarks.iscurrent(repo, bm)
        ret = hg.update(repo, c.rev())
        if not ret and shouldmove:
            repo._bookmarks[bm] = c.node()
            repo._bookmarks.write()
        displayer.show(c)
        return 0
    else:
        for c in children:
            displayer.show(c)
        ui.warn(_('multiple non-obsolete children, explicitly update to one\n'))
        return 1

def _reachablefrombookmark(repo, revs, mark):
    """filter revisions and bookmarks reachable from the given bookmark
    yoinked from mq.py
    """
    marks = repo._bookmarks
    if mark not in marks:
        raise util.Abort(_("bookmark '%s' not found") % mark)

    # If the requested bookmark is not the only one pointing to a
    # a revision we have to only delete the bookmark and not strip
    # anything. revsets cannot detect that case.
    uniquebm = True
    for m, n in marks.iteritems():
        if m != mark and n == repo[mark].node():
            uniquebm = False
            break
    if uniquebm:
        rsrevs = repo.revs("ancestors(bookmark(%s)) - "
                           "ancestors(head() and not bookmark(%s)) - "
                           "ancestors(bookmark() and not bookmark(%s)) - "
                           "obsolete()",
                           mark, mark, mark)
        revs.update(set(rsrevs))
    return marks,revs

def _deletebookmark(ui, marks, mark):
    del marks[mark]
    marks.write()
    ui.write(_("bookmark '%s' deleted\n") % mark)



def _getmetadata(**opts):
    metadata = {}
    date = opts.get('date')
    user = opts.get('user')
    if date:
        metadata['date'] = '%i %i' % util.parsedate(date)
    if user:
        metadata['user'] = user
    return metadata


@command('^prune|obsolete|kill',
    [('n', 'new', [], _("successor changeset (DEPRECATED)")),
     ('s', 'succ', [], _("successor changeset")),
     ('r', 'rev', [], _("revisions to prune")),
     ('', 'biject', False, _("do a 1-1 map between rev and successor ranges")),
     ('B', 'bookmark', '', _("remove revs only reachable from given"
                             " bookmark"))] + metadataopts,
    _('[OPTION] [-r] REV...'))
    # -U  --noupdate option to prevent wc update and or bookmarks update ?
def cmdprune(ui, repo, *revs, **opts):
    """hide changesets by marking them obsolete

    Obsolete changesets becomes invisible to all commands.

    Unpruned descendants of pruned changesets becomes "unstable". Use the
    :hg:`evolve` to handle such situation.

    When the working directory parent is pruned, the repository is updated to a
    non-obsolete parent.

    You can use the ``--succ`` option to inform mercurial that a newer version
    of the pruned changeset exists.

    You can use the ``--biject`` option to specify a 1-1 (bijection) between
    revisions to prune and successor changesets. This option may be removed in
    a future release (with the functionality absorbed automatically).

    """
    revs = set(scmutil.revrange(repo, list(revs) + opts.get('rev')))
    succs = opts['new'] + opts['succ']
    bookmark = opts.get('bookmark')
    metadata = _getmetadata(**opts)
    biject = opts.get('biject')

    if bookmark:
        marks,revs = _reachablefrombookmark(repo, revs, bookmark)
        if not revs:
            # no revisions to prune - delete bookmark immediately
            _deletebookmark(ui, marks, bookmark)

    if not revs:
        raise util.Abort(_('nothing to prune'))

    wlock = lock = None
    wlock = repo.wlock()
    sortedrevs = lambda specs: sorted(set(scmutil.revrange(repo, specs)))
    try:
        lock = repo.lock()
        # defines pruned changesets
        precs = []
        for p in sortedrevs(revs):
            cp = repo[p]
            if not cp.mutable():
                # note: createmarkers() would have raised something anyway
                raise util.Abort('cannot prune immutable changeset: %s' % cp,
                                 hint='see "hg help phases" for details')
            precs.append(cp)
        if not precs:
            raise util.Abort('nothing to prune')

        # defines successors changesets
        sucs = tuple(repo[n] for n in sortedrevs(succs))
        if not biject and len(sucs) > 1 and len(precs) > 1:
            msg = "Can't use multiple successors for multiple precursors"
            raise util.Abort(msg)

        if biject and len(sucs) != len(precs):
            msg = "Can't use %d successors for %d precursors" % (len(sucs), len(precs))
            raise util.Abort(msg)

        relations = [(p, sucs) for p in precs]
        if biject:
            relations = [(p, (s,)) for p, s in zip(precs, sucs)]

        # create markers
        createmarkers(repo, relations, metadata=metadata)

        # informs that changeset have been pruned
        ui.status(_('%i changesets pruned\n') % len(precs))
        # update to an unkilled parent
        wdp = repo['.']
        newnode = wdp
        while newnode.obsolete():
            newnode = newnode.parents()[0]
        if newnode.node() != wdp.node():
            commands.update(ui, repo, newnode.rev())
            ui.status(_('working directory now at %s\n') % newnode)
        # update bookmarks
        if bookmark:
            _deletebookmark(ui, marks, bookmark)
        for ctx in repo.unfiltered().set('bookmark() and %ld', precs):
            ldest = list(repo.set('max((::%d) - obsolete())', ctx))
            if ldest:
                dest = ldest[0]
                updatebookmarks = _bookmarksupdater(repo, ctx.node())
                updatebookmarks(dest.node())
    finally:
        lockmod.release(lock, wlock)

@command('amend|refresh',
    [('A', 'addremove', None,
     _('mark new/missing files as added/removed before committing')),
    ('e', 'edit', False, _('invoke editor on commit messages')),
    ('', 'close-branch', None,
     _('mark a branch as closed, hiding it from the branch list')),
    ('s', 'secret', None, _('use the secret phase for committing')),
    ] + walkopts + commitopts + commitopts2,
    _('[OPTION]... [FILE]...'))
def amend(ui, repo, *pats, **opts):
    """combine a changeset with updates and replace it with a new one

    Commits a new changeset incorporating both the changes to the given files
    and all the changes from the current parent changeset into the repository.

    See :hg:`commit` for details about committing changes.

    If you don't specify -m, the parent's message will be reused.

    Behind the scenes, Mercurial first commits the update as a regular child
    of the current parent. Then it creates a new commit on the parent's parents
    with the updated contents. Then it changes the working copy parent to this
    new combined changeset. Finally, the old changeset and its update are hidden
    from :hg:`log` (unless you use --hidden with log).

    Returns 0 on success, 1 if nothing changed.
    """
    opts = opts.copy()
    edit = opts.pop('edit', False)
    opts['amend'] = True
    if not (edit or opts['message']):
        opts['message'] = repo['.'].description()
    _alias, commitcmd = cmdutil.findcmd('commit', commands.table)
    return commitcmd[0](ui, repo, *pats, **opts)

def _commitfiltered(repo, ctx, match):
    """Recommit ctx with changed files not in match. Return the new
    node identifier, or None if nothing changed.
    """
    base = ctx.p1()
    m, a, r = repo.status(base, ctx)[:3]
    allfiles = set(m + a + r)
    files = set(f for f in allfiles if not match(f))
    if files == allfiles:
        return None

    # Filter copies
    copied = copies.pathcopies(base, ctx)
    copied = dict((src, dst) for src, dst in copied.iteritems()
                  if dst in files)
    def filectxfn(repo, memctx, path):
        if path not in ctx:
            raise IOError()
        fctx = ctx[path]
        flags = fctx.flags()
        mctx = context.memfilectx(fctx.path(), fctx.data(),
                                  islink='l' in flags,
                                  isexec='x' in flags,
                                  copied=copied.get(path))
        return mctx

    new = context.memctx(repo,
                         parents=[base.node(), node.nullid],
                         text=ctx.description(),
                         files=files,
                         filectxfn=filectxfn,
                         user=ctx.user(),
                         date=ctx.date(),
                         extra=ctx.extra())
    # commitctx always create a new revision, no need to check
    newid = repo.commitctx(new)
    return newid

def _uncommitdirstate(repo, oldctx, match):
    """Fix the dirstate after switching the working directory from
    oldctx to a copy of oldctx not containing changed files matched by
    match.
    """
    ctx = repo['.']
    ds = repo.dirstate
    copies = dict(ds.copies())
    m, a, r = repo.status(oldctx.p1(), oldctx, match=match)[:3]
    for f in m:
        if ds[f] == 'r':
            # modified + removed -> removed
            continue
        ds.normallookup(f)

    for f in a:
        if ds[f] == 'r':
            # added + removed -> unknown
            ds.drop(f)
        elif ds[f] != 'a':
            ds.add(f)

    for f in r:
        if ds[f] == 'a':
            # removed + added -> normal
            ds.normallookup(f)
        elif ds[f] != 'r':
            ds.remove(f)

    # Merge old parent and old working dir copies
    oldcopies = {}
    for f in (m + a):
        src = oldctx[f].renamed()
        if src:
            oldcopies[f] = src[0]
    oldcopies.update(copies)
    copies = dict((dst, oldcopies.get(src, src))
                  for dst, src in oldcopies.iteritems())
    # Adjust the dirstate copies
    for dst, src in copies.iteritems():
        if (src not in ctx or dst in ctx or ds[dst] != 'a'):
            src = None
        ds.copy(src, dst)

@command('^uncommit',
    [('a', 'all', None, _('uncommit all changes when no arguments given')),
     ] + commands.walkopts,
    _('[OPTION]... [NAME]'))
def uncommit(ui, repo, *pats, **opts):
    """move changes from parent revision to working directory

    Changes to selected files in the checked out revision appear again as
    uncommitted changed in the working directory. A new revision
    without the selected changes is created, becomes the checked out
    revision, and obsoletes the previous one.

    The --include option specifies patterns to uncommit.
    The --exclude option specifies patterns to keep in the commit.

    Return 0 if changed files are uncommitted.
    """
    lock = repo.lock()
    try:
        wlock = repo.wlock()
        try:
            wctx = repo[None]
            if len(wctx.parents()) <= 0:
                raise util.Abort(_("cannot uncommit null changeset"))
            if len(wctx.parents()) > 1:
                raise util.Abort(_("cannot uncommit while merging"))
            old = repo['.']
            if old.phase() == phases.public:
                raise util.Abort(_("cannot rewrite immutable changeset"))
            if len(old.parents()) > 1:
                raise util.Abort(_("cannot uncommit merge changeset"))
            oldphase = old.phase()
            updatebookmarks = _bookmarksupdater(repo, old.node())
            # Recommit the filtered changeset
            newid = None
            if (pats or opts.get('include') or opts.get('exclude')
                or opts.get('all')):
                match = scmutil.match(old, pats, opts)
                newid = _commitfiltered(repo, old, match)
            if newid is None:
                raise util.Abort(_('nothing to uncommit'))
            # Move local changes on filtered changeset
            createmarkers(repo, [(old, (repo[newid],))])
            phases.retractboundary(repo, oldphase, [newid])
            repo.dirstate.setparents(newid, node.nullid)
            _uncommitdirstate(repo, old, match)
            updatebookmarks(newid)
            if not repo[newid].files():
                ui.warn(_("new changeset is empty\n"))
                ui.status(_('(use "hg prune ." to remove it)\n'))
        finally:
            wlock.release()
    finally:
        lock.release()

@eh.wrapcommand('commit')
def commitwrapper(orig, ui, repo, *arg, **kwargs):
    if kwargs.get('amend', False):
        lock = None
    else:
        lock = repo.lock()
    try:
        obsoleted = kwargs.get('obsolete', [])
        if obsoleted:
            obsoleted = repo.set('%lr', obsoleted)
        result = orig(ui, repo, *arg, **kwargs)
        if not result: # commit successed
            new = repo['-1']
            oldbookmarks = []
            markers = []
            for old in obsoleted:
                oldbookmarks.extend(repo.nodebookmarks(old.node()))
                markers.append((old, (new,)))
            if markers:
                createmarkers(repo, markers)
            for book in oldbookmarks:
                repo._bookmarks[book] = new.node()
            if oldbookmarks:
                repo._bookmarks.write()
        return result
    finally:
        if lock is not None:
            lock.release()

@command('^touch',
    [('r', 'rev', [], 'revision to update'),
     ('D', 'duplicate', False,
      'do not mark the new revision as successor of the old one')],
    # allow to choose the seed ?
    _('[-r] revs'))
def touch(ui, repo, *revs, **opts):
    """Create successors that are identical to their predecessors except for the changeset ID

    This is used to "resurrect" changesets
    """
    duplicate = opts['duplicate']
    revs = list(revs)
    revs.extend(opts['rev'])
    if not revs:
        revs = ['.']
    revs = scmutil.revrange(repo, revs)
    if not revs:
        ui.write_err('no revision to touch\n')
        return 1
    if not duplicate and repo.revs('public() and %ld', revs):
        raise util.Abort("can't touch public revision")
    wlock = lock = None
    try:
        wlock = repo.wlock()
        lock = repo.lock()
        tr = repo.transaction('touch')
        revs.sort() # ensure parent are run first
        newmapping = {}
        try:
            for r in revs:
                ctx = repo[r]
                extra = ctx.extra().copy()
                extra['__touch-noise__'] = random.randint(0, 0xffffffff)
                # search for touched parent
                p1 = ctx.p1().node()
                p2 = ctx.p2().node()
                p1 = newmapping.get(p1, p1)
                p2 = newmapping.get(p2, p2)
                new, _ = rewrite(repo, ctx, [], ctx,
                                 [p1, p2],
                                 commitopts={'extra': extra})
                # store touched version to help potential children
                newmapping[ctx.node()] = new
                if not duplicate:
                    createmarkers(repo, [(ctx, (repo[new],))])
                phases.retractboundary(repo, ctx.phase(), [new])
                if ctx in repo[None].parents():
                    repo.dirstate.setparents(new, node.nullid)
            tr.close()
        finally:
            tr.release()
    finally:
        lockmod.release(lock, wlock)

@command('^fold',
    [('r', 'rev', [], _("explicitly specify the full set of revision to fold")),
    ] + commitopts2,
    # allow to choose the seed ?
    _('rev'))
def fold(ui, repo, *revs, **opts):
    """Fold multiple revisions into a single one

    The revisions from your current working directory to the given one are folded
    into a single successor revision.

    you can alternatively use --rev to explicitly specify revisions to be folded,
    ignoring the current working directory parent.
    """
    revs = list(revs)
    if revs:
        if opts.get('rev', ()):
            raise util.Abort("cannot specify both --rev and a target revision")
        targets = scmutil.revrange(repo, revs)
        revs = repo.revs('(%ld::.) or (.::%ld)', targets, targets)
    elif 'rev' in opts:
        revs = scmutil.revrange(repo, opts['rev'])
    else:
        revs = ()
    if not revs:
        ui.write_err('no revision to fold\n')
        return 1
    roots = repo.revs('roots(%ld)', revs)
    if len(roots) > 1:
        raise util.Abort("set has multiple roots")
    root = repo[roots[0]]
    if root.phase() <= phases.public:
        raise util.Abort("can't fold public revisions")
    heads = repo.revs('heads(%ld)', revs)
    if len(heads) > 1:
        raise util.Abort("set has multiple heads")
    head = repo[heads[0]]
    wlock = lock = None
    try:
        wlock = repo.wlock()
        lock = repo.lock()
        tr = repo.transaction('touch')
        try:
            commitopts = opts.copy()
            allctx = [repo[r] for r in revs]
            targetphase = max(c.phase() for c in allctx)
            msgs = ["HG: This is a fold of %d changesets." % len(allctx)]
            msgs += ["HG: Commit message of changeset %s.\n\n%s\n" %
                     (c.rev(), c.description()) for c in allctx]
            commitopts['message'] = "\n".join(msgs)
            commitopts['edit'] = True
            newid, _ = rewrite(repo, root, allctx, head,
                             [root.p1().node(), root.p2().node()],
                             commitopts=commitopts)
            phases.retractboundary(repo, targetphase, [newid])
            createmarkers(repo, [(ctx, (repo[newid],))
                                 for ctx in allctx])
            tr.close()
        finally:
            tr.release()
        ui.status('%i changesets folded\n' % len(revs))
        if repo['.'].rev() in revs:
            hg.update(repo, newid)
    finally:
        lockmod.release(lock, wlock)



@eh.wrapcommand('graft')
def graftwrapper(orig, ui, repo, *revs, **kwargs):
    kwargs = dict(kwargs)
    revs = list(revs) + kwargs.get('rev', [])
    kwargs['rev'] = []
    obsoleted = kwargs.setdefault('obsolete', [])

    lock = repo.lock()
    try:
        if kwargs.get('old_obsolete'):
            if kwargs.get('continue'):
                obsoleted.extend(repo.opener.read('graftstate').splitlines())
            else:
                obsoleted.extend(revs)
        # convert obsolete target into revs to avoid alias joke
        obsoleted[:] = [str(i) for i in repo.revs('%lr', obsoleted)]
        if obsoleted and len(revs) > 1:

            raise error.Abort(_('cannot graft multiple revisions while '
                                'obsoleting (for now).'))

        return commitwrapper(orig, ui, repo,*revs, **kwargs)
    finally:
        lock.release()

@eh.extsetup
def oldevolveextsetup(ui):
    try:
        rebase = extensions.find('rebase')
    except KeyError:
        raise error.Abort(_('evolution extension requires rebase extension.'))

    for cmd in ['kill', 'uncommit', 'touch', 'fold']:
        entry = extensions.wrapcommand(cmdtable, cmd,
                                       warnobserrors)

    entry = cmdutil.findcmd('commit', commands.table)[1]
    entry[1].append(('o', 'obsolete', [],
                     _("make commit obsolete this revision")))
    entry = cmdutil.findcmd('graft', commands.table)[1]
    entry[1].append(('o', 'obsolete', [],
                     _("make graft obsoletes this revision")))
    entry[1].append(('O', 'old-obsolete', False,
                     _("make graft obsoletes its source")))

