#!/usr/bin/env python

import os

badges = []
try:
   if 'WP' in os.environ:
      execfile( '/eng/project/{}/settings'.format( os.environ[ 'WP' ] ) )
      badges.append( '{}[{}]'.format( os.environ[ 'WP' ].split( '.', 1 )[ 1 ],
                                   parent ) )
      mps = globals().get('memberPackages', [])
      badges.append( ' | '.join( [ mp.split( '/', 1 )[ 0 ] for mp in mps ] ) )
except Exception as e:
      badges.append( ' *Error*: {}'.format( e ) )

for i, b in enumerate( badges ) :
   print 'iterm2_set_user_var badge{} "{}{}";'.format( i, '\n' if i > 0 else '', b )
