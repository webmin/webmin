use strict;
use warnings;
do 'acl-lib.pl';
our (%text, %in);

# acl_security_form(&options)
# Output HTML for editing security options for the acl module
sub acl_security_form
{
my ($o) = @_;

print &ui_table_row($text{'acl_show'},
	&ui_radio("show_def", $o->{'show'} eq '*' ? 1 : 0,
		  [ [ 1, $text{'acl_showall'} ],
		    [ 0, $text{'acl_showsel'} ] ])."<br>\n".
	&ui_select("show", [ split(/\s+/, $o->{'show'}) ],
		   [ [ 'host', $text{'acl_host'} ],
		     [ 'cpu', $text{'acl_cpu'} ],
		     [ 'temp', $text{'acl_temp'} ],
		     [ 'load', $text{'acl_load'} ],
		     [ 'mem', $text{'acl_mem'} ],
		     [ 'disk', $text{'acl_disk'} ],
		     [ 'poss', $text{'acl_poss'} ] ], 7, 1));
}

# acl_security_save(&options, &in)
# Parse the form for security options for the acl module
sub acl_security_save
{
my ($o, $in) = @_;
if ($in->{'show_def'}) {
	$o->{'show'} = '*';
	}
else {
	$o->{'show'} = join(' ', split(/\0/, $in->{'show'}));
	}
}
