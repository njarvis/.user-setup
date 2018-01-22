#!/usr/bin/env python
# -*- coding: utf-8 -*-
# Copyright (c) 2017 Arista Networks, Inc.  All rights reserved.
# Arista Networks, Inc. Confidential and Proprietary.

from __future__ import print_function

import json
import os
import re
import subprocess
import sys
import time
import uuid

profilePlist = os.path.expanduser( '~/Library/Application Support'
                                   '/iTerm2/DynamicProfiles/a4-clients' )
user = os.environ[ 'USER' ]

def cached_property( f ):
    """returns a cached property that is calculated by function f"""
    def get( self ):
        try:
            return self._property_cache[ f ]
        except AttributeError:
            self._property_cache = {}
            x = self._property_cache[ f ] = f( self )
            return x
        except KeyError:
            x = self._property_cache[ f ] = f( self )
            return x

    return property( get )

class Profile( object ):
   _shortcuts = {}

   def __init__( self, parentProfile, rows=50, columns=132, shortcut=None ):
      self._guid = str( uuid.uuid4() )
      self._parentProfile = parentProfile
      self._rows = rows
      self._columns = columns
      self.shortcut = shortcut

   @property
   def guid( self ):
      return self._guid

   @guid.setter
   def guid( self, value ):
      self._guid = value

   @property
   def parentProfile( self ):
      return self._parentProfile

   @property
   def columns( self ):
      return self._columns

   @property
   def rows( self ):
      return self._rows

   @property
   def shortcut( self ):
      return self._shortcut

   @shortcut.setter
   def shortcut( self, value ):
      if value is None or value == "":
         self._shortcut = ""
      else:
         if value in self._shortcuts:
            raise ValueError( 'Shortcut %s already in use by %s' %
                              ( value, self._shortcuts[ value ] ) )
         else:
            self._shortcut = value
            self._shortcuts[ value ] = self

   def profile( self, merge=None ):
      p = { 'Guid': self.guid,
            'Columns': self.columns,
            'Rows': self.rows,
            'Bound Hosts': [],
            'Dynamic Profile Parent Name': self.parentProfile,
            'Shortcut': self.shortcut,
            'A4Clients': { 'Testing': 1, 'Test': [] } }
      if merge:
         p.update( merge )
      return p

class Client( Profile ):
   _domain = 'sjc.aristanetworks.com'
   _clientShortcut = '0'

   def __init__( self, user, project, iteration, clientHost, clientRegion ):
      super( Client, self ).__init__( 'Workspace Container' )
      self._user = user
      self._project = project
      self._iteration = iteration
      self._clientHost = clientHost
      self._clientRegion = clientRegion

      # Allocate our next shortcut
      self.shortcut = Client._clientShortcut
      Client._clientShortcut = chr( ord( Client._clientShortcut ) + 1 )

   @property
   def user( self ):
      return self._user

   @property
   def project( self ):
      return self._project

   @property
   def iteration( self ):
      return self._iteration

   @property
   def clientHost( self ):
      return self._clientHost

   @property
   def clientRegion( self ):
      return self._clientRegion

   @property
   def clientHostname( self ):
      return '.'.join( [ self.clientHost, self.clientRegion ] )

   @property
   def host( self ):
      return '%s-%s-%s.%s' % ( self.user, self.project,
                               self.iteration, self._domain )

   @property
   def session( self ):
      return '%s-%s-%s' % ( self.project, self.iteration, self.clientHost )

   @property
   def bugId( self ):
      bugMatch = re.match( r"b(\d+)", self.project )
      return bugMatch.group( 1 ) if bugMatch else None

   @property
   def rfeId( self ):
      rfeMatch = re.match( r"rfe(\d+)", self.project )
      return rfeMatch.group( 1 ) if rfeMatch else None

   @cached_property
   def name( self ):
      bugzillaId = self.bugId or self.rfeId
      if bugzillaId:
         try:
            bugSummary = subprocess.check_output( '/usr/local/bin/a4 bugs -q '
                                                  + bugzillaId,
                                                  shell=True ).strip()
            bugSummaryFields = re.split( r'\s+', bugSummary, 4 )
            name = '%s: [%s] %s' % ( self.session,
                                     bugSummaryFields[ 3 ],
                                     bugSummaryFields[ 4 ] )
         except:
            pass
         else:
            return name

      return self.host

   @property
   def tags( self ):
      if self.bugId:
         return [ u'0\ufe0f\u20e3 Bugs', u'0\ufe0f\u20e3 Bugs/' + self.clientHostname ]
      elif self.rfeId:
         return [ u'1\ufe0f\u20e3 RFEs', u'1\ufe0f\u20e3 RFEs/' + self.clientHostname ]
      else:
         return [ u'2\ufe0f\u20e3 Projects', u'2\ufe0f\u20e3 Projects/' + self.clientHostname ]

   def profile( self, merge=None ):
      return super( Client, self ).profile( {
         'Name': self.name,
         'Guid': self.guid,
         'Custom Command': 'Yes',
         'Command': ( 'ssh -t %s@%s $HOME/bin/start-tmux %s' %
                      ( self.user, self.host, self.session ) ),
         'Tags': self.tags, } )

class UserServer( Profile ):
   _userServerShortcut = 'A'

   def __init__( self, user, host ):
      super( UserServer, self ).__init__( 'User Server' )
      self._user = user
      self._host = host

      # Allocate our next shortcut
      self.shortcut = UserServer._userServerShortcut
      UserServer._userServerShortcut = chr( ord( UserServer._userServerShortcut ) +
                                            1 )

   @property
   def user( self ):
      return self._user

   @property
   def host( self ):
      return self._host

   @property
   def session( self ):
      return self.host.split( '.', 1 )[ 0 ]

   @property
   def name( self ):
      return '.'.join( self.host.split( '.', 2 )[ :2 ] )

   @property
   def tags( self ):
      return [ u'3\ufe0f\u20e3 User Servers' ]

   def profile( self, merge=None ):
      return super( UserServer, self ).profile( {
         'Name': self.name,
         'Guid': self.guid,
         'Custom Command': 'Yes',
         'Command': ( '/usr/local/bin/mosh %s@%s -- /home/%s/bin/start-tmux %s' %
                      ( self.user, self.host, self.user, self.session ) ),
         'Tags': self.tags, } )

if __name__ == '__main__':
   import argparse

   parser = argparse.ArgumentParser( description='Generate dynamic iTerm profiles '
                                     'from a4 client' )
   parser.add_argument( '-i', '--incremental', action='store_true',
                        help='Only update profiles if anything changed' )
   parser.add_argument( '-u', '--update', action='store_true',
                        help='Update the profile file' )
   parser.add_argument( '-v', '--verbose', action='store_true',
                        help='Show progress' )

   args = parser.parse_args()

   profiles = []

   FNULL = open( os.devnull, 'w' )

   # Make sure we are logged in
   a4loginP = subprocess.Popen( [ 'a4', 'login', '-s' ],
                                stdout=FNULL,
                                stderr=subprocess.STDOUT )
   if a4loginP.wait():
      keyringP = subprocess.Popen( [ 'keyring', 'get', 'a4-clients.py', user ],
                                   stdout=subprocess.PIPE )
      a4loginP = subprocess.Popen( [ 'a4', 'login' ],
                                   stdin=keyringP.stdout, stdout=FNULL,
                                   stderr=subprocess.STDOUT )
      keyringP.stdout.close()
      a4loginP.wait()

   a4clientsP = subprocess.Popen( [ 'a4', 'clients', '-u', user ],
                                  stdout=subprocess.PIPE )

   if args.verbose: print( 'Fetching a4 clients...' )

   for l in a4clientsP.communicate()[ 0 ].splitlines():
      ( _s, name, _s, _s, root, _s ) = l.split( ' ', 5 )
      if root == '/':
         u, p, i = name.split( '.', 2 )
         a4clientP = subprocess.Popen( [ 'a4', 'client', '-o', name ],
                                       stdout=subprocess.PIPE )
         if args.verbose: print( 'Examining a4 client %s...' % name )
         for ll in a4clientP.communicate()[ 0 ].splitlines():
            if ll.startswith( 'Host:' ):
               try:
                  hostname = ll.split()[ 1 ]
               except:
                  pass
               else:
                  h = hostname.split( '.' )[ :2 ]
                  c = Client( u, p, i, *h )

         profiles.append( c.profile() )

   if args.verbose: print( 'Enumerating user servers...' )

   for us in [ 'us152.sjc.aristanetworks.com', 'us804.ire.aristanetworks.com' ]:
      c = UserServer( user, us )
      profiles.append( c.profile() )

   dynamicProfiles = { 'Profiles': profiles }

   if args.incremental:
      with open( profilePlist, 'r' ) as plist:
         existingProfiles = json.load( plist )

         for profile in existingProfiles[ 'Profiles' ]:
            print( profile )

   if args.update:
      with open( profilePlist, 'w' ) as plist:
         print( json.dumps( dynamicProfiles, indent=4, sort_keys=True ), file=plist )

      from pyfiglet import Figlet
      f = Figlet( )
      print( f.renderText( "iTerm Dynamic Profiles Updated" ), file=sys.stderr )
      time.sleep( 2 )
   else:
      print( json.dumps( dynamicProfiles, indent=4, sort_keys=True ) )
