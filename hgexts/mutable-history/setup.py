# Copied from histedit setup.py
# Credit to Augie Fackler <durin42@gmail.com>

from distutils.core import setup

setup(
    name='hg-evolve',
    version='3.3.1',
    author='Pierre-Yves David',
    maintainer='Pierre-Yves David',
    maintainer_email='pierre-yves.david@ens-lyon.org',
    url='https://bitbucket.org/marmoute/mutable-history',
    description='Flexible evolution of Mercurial history.',
    long_description=open('README').read(),
    keywords='hg mercurial',
    license='GPLv2+',
    py_modules=['hgext.evolve', 'hgext.pushexperiment'],
)
