
use strict;
use warnings;
no warnings 'redefine';
no warnings 'uninitialized';
do 'servers-lib.pl';
our (%config, %text);

sub show_deftype
{
return ( $text{'config_deftype'}, 4,
	 "-$text{'default'}",
	 map { $_->[0]."-".$_->[1] } &get_server_types() );
}

1;

