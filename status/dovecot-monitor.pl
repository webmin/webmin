# Monitor the Dovecot server on this host

sub get_dovecot_status
{
local ($serv, $mod) = @_;
return { 'up' => -1 } if (!&foreign_check($mod));
&foreign_require($mod);
local $r = &foreign_call($mod, "is_dovecot_running");
if ($r > 0) {
	return { 'up' => 1 };
	}
else {
	return { 'up' => 0 };
	}
}

1;

