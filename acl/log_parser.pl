# log_parser.pl
# Functions for parsing this module's logs

use strict;
use warnings;
do 'acl-lib.pl';
our (%text);

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
my ($user, $script, $action, $type, $object, $p) = @_;
my $g = $type eq 'group' ? "_g" : "";
if ($action eq 'modify') {
	if ($p->{'old'} ne $p->{'name'}) {
		return &text('log_rename'.$g, "<tt>$p->{'old'}</tt>",
					      "<tt>$p->{'name'}</tt>");
		}
	else {
		return &text('log_modify'.$g,
			     "<tt>".&html_escape($object)."</tt>");
		}
	}
elsif ($action eq 'create') {
	if ($p->{'clone'}) {
		return &text('log_clone'.$g, "<tt>$p->{'clone'}</tt>",
			     "<tt>".&html_escape($object)."</tt>");
		}
	else {
		return &text('log_create'.$g,
			     "<tt>".&html_escape($object)."</tt>");
		}
	}
elsif ($action eq 'delete') {
	if ($type eq "users" || $type eq "groups") {
		return &text('log_delete_'.$type, $object);
		}
	else {
		return &text('log_delete'.$g, "<tt>$object</tt>");
		}
	}
elsif ($action eq 'joingroup') {
	return &text('log_joingroup', $object, $p->{'group'});
	}
elsif ($action eq 'acl') {
	return &text('log_acl', "<tt>$object</tt>",
		     "<i>".&html_escape($p->{'moddesc'})."</i>");
	}
elsif ($action eq 'reset') {
	return &text('log_reset', "<tt>$object</tt>",
		     "<i>".&html_escape($p->{'moddesc'})."</i>");
	}
elsif ($action eq 'cert') {
	return &text('log_cert', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'switch') {
	return &text('log_switch', "<tt>".&html_escape($object)."</tt>");
	}
elsif ($action eq 'twofactor') {
	return &text('log_twofactor', $object, $p->{'provider'}, $p->{'id'});
	}
else {
	return $text{'log_'.$action};
	}
}

