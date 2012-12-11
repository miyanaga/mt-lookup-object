use strict;
use FindBin qw($Bin);
use lib $Bin;
use MTPath;
use Test::More;
use MT::Plugins::Test::Object;
use MT::Plugins::Test::Template;

use_ok 'MT::LookupObject::Tags';

done_testing;