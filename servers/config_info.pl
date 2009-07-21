
do 'servers-lib.pl';

sub show_deftype
{
return ( $text{'config_typeauto'}, 4,
	 "-$text{'default'}",
	 map { $_->[0]."-".$_->[1] } @server_types );
}

1;

