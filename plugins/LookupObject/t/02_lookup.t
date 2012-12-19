use strict;
use FindBin qw($Bin);
use lib $Bin;
use MTPath;
use Test::More;
use MT::Plugins::Test::Object;
use MT::Plugins::Test::Template;

test_common_website(
    as_superuser => 1,
    no_themes => 1,
    test => sub {
        my ( $website, $blog, $user, $password ) = @_;
        my $sid = $website->id;
        my $bid = $blog->id;

        my @indexes = (1..10);
        my %entries;
        foreach ( @indexes ) {
            $entries{"entry_$_"} = {
                blog_id => $blog->id,
                title => "Entry $_",
                basename => "entry_$_",
                text => "Body of $_",
            };
        }

        test_objects(
            model => 'entry',
            template => 'common_entry',
            values => \%entries,
            test => sub {
                my $objects = shift;

                test_template(
                    stash => { blog => $website },
                    template => qq{
<mt:LookupEntry title="Entry 1" blog_id="$bid"><mt:EntryBasename></mt:LookupEntry>
<mt:LookupEntry basename="entry_2" blog_id="$bid"><mt:EntryTitle></mt:LookupEntry>
<mt:LookupEntry basename="entry_2" blog_id="$sid"><mt:EntryTitle></mt:LookupEntry>
<mt:LookupEntry basename="entry_3" blog_id="$bid" pre_fetch="1"><mt:EntryTitle></mt:LookupEntry>
<mt:LookupEntry basename="entry_4" blog_id="$bid" pre_fetch="1"><mt:EntryTitle></mt:LookupEntry>
<mt:setvar name="title" value="outside">
<mt:var name="title"><mt:LookupEntry basename="entry_1" as_vars="1"><mt:var name="title"></mt:LookupEntry><mt:var name="title">
},
                    test => sub {
                        my %args = @_;

                        is $args{result}, qq{
entry_1
Entry 2

Entry 3
Entry 4

outsideEntry 1outside
}, 'Lookup some entries.';

                        ok $args{ctx}->{__stash}{__lookup_tables}{entry}{$bid}{basename}, 'Pre fetch table created';
                        is scalar(keys(%{$args{ctx}->{__stash}{__lookup_tables}{entry}{$bid}{basename}})), 10, 'Pre fetch table has 10 entries';
                    },
                );
            },
        );
    },
);

done_testing;