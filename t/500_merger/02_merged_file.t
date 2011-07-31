use strict;
use warnings;

use Test::More;

use Testgen::Merger::MergedFile;

{
    can_ok('Testgen::Merger::MergedFile', 'create_mergedfile');
}

{
    eval {
        my $merged_file = Testgen::Merger::MergedFile->create_mergedfile();
    };
    like $@, qr/missing mandatory parameter/, 'not speficied lang';

    eval {
        my $merged_file = Testgen::Merger::MergedFile->create_mergedfile(
            lang => 'NOT_EXIST_LANG',
        );
    };
    like $@, qr/is not implemented yet/, 'not supported language';
}

done_testing;
