'''enable experimental obsolescence feature of Mercurial

OBSOLESCENCE IS AN EXPERIMENTAL FEATURE MAKE SURE YOU UNDERSTOOD THE INVOLVED
CONCEPT BEFORE USING IT.

/!\ THIS EXTENSION IS INTENDED FOR SERVER SIDE ONLY USAGE /!\

For client side usages it is recommended to use the evolve extension for
improved user interface.'''

import mercurial.obsolete
mercurial.obsolete._enabled = True
