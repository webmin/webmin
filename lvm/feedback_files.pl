
sub feedback_files
{
return ( "/proc/lvm/global", glob("/proc/lvm/VGs/*/group"),
	 glob("/proc/lvm/VGs/*/PVs/*"), glob("/proc/lvm/VGs/*/LVs/*") );
}

1;

