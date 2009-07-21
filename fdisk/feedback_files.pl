
do 'fdisk-lib.pl';

sub feedback_files
{
return ( "/proc/partitions", "/proc/scsi/scsi",
	 "fdisk -l |" );
}

1;

