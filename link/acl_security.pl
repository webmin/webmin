
BEGIN { push(@INC, ".."); };
use WebminCore;
&init_config();

sub acl_security_form
{
print &ui_table_row($text{'acl_link'},
	&ui_textbox("link", $_[0]->{'link'}, 50));
}

sub acl_security_save
{
$in{'link'} =~ /\S/ || &error($text{'acl_elink'});
$_[0]->{'link'} = $in{'link'};
}

