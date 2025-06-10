
do 'proftpd-lib.pl';

sub feedback_files
{
local $conf = &get_config();
return &unique(map { $_->{'file'} } @$conf);

}

1;

