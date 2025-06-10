# log_parser.pl
# Functions for parsing this module's logs

do 'sendmail-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
if ($type eq 'alias' || $type eq 'virtuser' || $type eq 'mailer' ||
    $type eq 'generic' || $type eq 'domain' || $type eq 'access') {
	return &text("log_${type}_${action}",
		     "<tt>".&html_escape($object)."</tt>");
	}
elsif ($type eq 'aliases' || $type eq 'virtusers' || $type eq 'mailers' ||
       $type eq 'generics' || $type eq 'domains' || $type eq 'accesses') {
	return &text("log_${action}_${type}", $object);
	}
elsif ($type eq 'feature') {
	return &text("log_feature_${action}",
		     "<tt>".&html_escape($p->{'text'})."</tt>");
	}
elsif ($action eq 'delmailq') {
	if ($p->{'from'}) {
		return &text("log_delmailq",
			     &html_escape(&extract_email($p->{'from'})));
		}
	else {
		return &text("log_delmailqs", $p->{'count'});
		}
	}
elsif ($action eq 'delmail') {
	local @d = split(/\0/, $p->{'d'});
	return &text("log_delmail", scalar(@d), "<tt>$p->{'user'}</tt>");
	}
elsif ($action eq 'movemail') {
	local @d = split(/\0/, $p->{'d'});
	local $to = $p->{'move1'} ? $p->{'moveto1'} : $p->{'moveto2'};
	return &text("log_movemail", scalar(@d), "<tt>$p->{'user'}</tt>",
		     "<tt>$to</tt>");
	}
elsif ($action eq 'send') {
	return &text('log_send', &html_escape(&extract_email($p->{'to'})));
	}
elsif ($text{"log_$action"}) {
	return $text{"log_$action"};
	}
else {
	return undef;
	}
}

sub extract_email
{
if ($_[0] =~ /([^<>"' \(\)]+\@[^<>"' \(\)]+)/) {
	return $1;
	}
elsif ($_[0] =~ /<(\S+)>/) {
	return $1;
	}
else {
	return $_[0];
	}
}

