{-

Copyright 2012, 2013 
Colin Woodbury <colingw@gmail.com>
Nicholas Clarke <nicholas.clarke@sanger.ac.uk>

This file is part of Aura.

Aura is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Aura is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Aura.  If not, see <http://www.gnu.org/licenses/>.

-}

module Aura.Virtual 
  ( VirtualPkg(..)
   ,providerPkgOf
   ,virtualPkg
   ,getProvidingPkg 
  ) where

import Aura.Core
import Aura.Monad.Aura
import Aura.Pacman (pacmanOutput)
import Aura.Utils (splitNameAndVer)

import Control.Monad    (liftM,when)
import Data.List        ((\\), nub, intercalate, isSuffixOf)

-------------------
-- Virtual Packages
-------------------
-- Virtual packages also contain a record of their providing package.
-- Providing packages are assumed to be Pacman (ABS) packages.
-- Are there any instances where this isn't the case?
data VirtualPkg = VirtualPkg String VersionDemand (Maybe PacmanPkg)

instance Package VirtualPkg where
    pkgNameOf (VirtualPkg n _ _) = n
    versionOf (VirtualPkg _ v _) = v

instance Show VirtualPkg where
    show = pkgNameWithVersionDemand

providerPkgOf :: VirtualPkg -> Maybe PacmanPkg
providerPkgOf (VirtualPkg _ _ p) = p

-------------------
-- working stuff
-------------------

virtualPkg :: String -> Aura VirtualPkg
virtualPkg pkg = VirtualPkg name ver `liftM` getProvider pkg
    where (name,ver) = parseNameAndVersionDemand pkg
          getProvider n = do
            provider <- getProvidingPkg n
            case provider of
              Nothing -> return Nothing
              Just p  -> Just `liftM` pacmanPkg p

-- Yields a virtual package's providing package if there is one.
getProvidingPkg :: String -> Aura (Maybe String)
getProvidingPkg virt = do
  candidates <- getProvidingPkg' virt
  let lined = lines candidates
  if length lined /= 1
     then return Nothing
     else return . Just . head $ lined

-- Unsafe version.
-- Only use on virtual packages that have guaranteed providers.
-- Adding "$" to the pkg name (technically a regex) fixes a bug.
getProvidingPkg' :: String -> Aura String
getProvidingPkg' virt = do
  let (name,_) = splitNameAndVer virt
  nub `liftM` pacmanOutput ["-Ssq",name ++ "$"]