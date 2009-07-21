# log_parser.pl
# Functions for parsing this module's logs

do 'proftpd-lib.pl';

# parse_webmin_log(user, script, action, type, object, &params, long)
# Converts logged information from this module into human-readable form
sub parse_webmin_log
{
local ($user, $script, $action, $type, $object, $p, $long) = @_;
local $typestr = "<i>".$text{"type_$type"}."</i>";
if ($action eq 'global') {
	return &text('log_global', $typestr);
	}
elsif ($action eq 'ftpusers') {
	return $text{'log_ftpusers'};
	}
elsif ($action eq 'virt') {
	$object = $object eq '-' ? $text{'index_defserv'}
				 : &html_escape($object);
	if ($type eq 'create') {
		return &text('log_virtc', "<tt>$object</tt>");
		}
	elsif ($type eq 'save') {
		return &text('log_virts', "<tt>$object</tt>");
		}
	elsif ($type eq 'delete') {
		return &text('log_virtd', "<tt>$object</tt>");
		}
	elsif ($type eq 'manual') {
		return &text('log_virtm', "<tt>$object</tt>");
		}
	else {
		return &text('log_virt', $typestr, "<tt>$object</tt>");
		}
	}
elsif ($action eq 'dir') {
	local ($virt, $dir) = split(/:/, $object);
	$virt = $virt ? &html_escape($virt) : $text{'index_defserv'};
	$dir = &html_escape($dir);
	if ($type eq 'create') {
		return &text($long ? 'log_dirc_l' : 'log_dirc',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'save') {
		return &text($long ? 'log_dirs_l' : 'log_dirs',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'delete') {
		return &text($long ? 'log_dird_l' : 'log_dird',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	elsif ($type eq 'manual') {
		return &text($long ? 'log_dirm_l' : 'log_dirm',
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	else {
		return &text($long ? 'log_dir_l' : 'log_dir', $typestr,
			     "<tt>$dir</tt>", "<tt>$virt</tt>");
		}
	}
elsif ($action eq 'limit') {
	if ($type eq 'create') {
		return &text('log_limitc', "<tt>$object</tt>");
		}
	elsif ($type eq 'save') {
		return &text('log_limits', "<tt>$object</tt>");
		}
	elsif ($type eq 'delete') {
		return &text('log_limitd', "<tt>$object</tt>");
		}
	elsif ($type eq 'manual') {
		return &text('log_limitm', "<tt>$object</tt>");
		}
	else {
		return &text('log_limit', $typestr, "<tt>$object</tt>");
		}
	}
elsif ($action eq 'ftpaccess') {
	if ($type eq 'create') {
		return &text('log_ftpaccessc', "<tt>$object</tt>");
		}
	elsif ($type eq 'save') {
		return &text('log_ftpaccesss', "<tt>$object</tt>");
		}
	elsif ($type eq 'delete') {
		return &text('log_ftpaccessd', "<tt>$object</tt>");
		}
	elsif ($type eq 'manual') {
		return &text('log_ftpaccessm', "<tt>$object</tt>");
		}
	else {
		return &text('log_ftpaccess', $typestr, "<tt>$object</tt>");
		}
	}
elsif ($action eq 'anon') {
	$object = $object eq '-' ? $text{'index_defserv'}
				 : &html_escape($object);
	if ($type eq 'create') {
		return &text('log_anonc', "<tt>$object</tt>");
		}
	elsif ($type eq 'save') {
		return &text('log_anons', "<tt>$object</tt>");
		}
	elsif ($type eq 'delete') {
		return &text('log_anond', "<tt>$object</tt>");
		}
	elsif ($type eq 'manual') {
		return &text('log_anonm', "<tt>$object</tt>");
		}
	else {
		return &text('log_anon', $typestr, "<tt>$object</tt>");
		}
	}
else {
	return $text{"log_$action"};
	}
}

