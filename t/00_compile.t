use strict;
use Test::More;

BEGIN {
    use_ok 'Testgen';
    use_ok 'Testgen::Config';
    use_ok 'Testgen::ForkManager';
    use_ok 'Testgen::Generator';
    use_ok 'Testgen::Log';
    TODO : {
        local $TODO = 'not implement now';
        use_ok 'Testgen::Merger';
    };
    use_ok 'Testgen::Runner';
    use_ok 'Testgen::Runner::Command';
    use_ok 'Testgen::Runner::Compiler';
    use_ok 'Testgen::Runner::Compiler::Result';
    use_ok 'Testgen::Runner::Executer';
    use_ok 'Testgen::Runner::Executer::Result';
    use_ok 'Testgen::Runner::Result';
    use_ok 'Testgen::TemplateFile';
    use_ok 'Testgen::TemplateFile::Macro';
    use_ok 'Testgen::TestDirectory';
    use_ok 'Testgen::TestDirectory::Test';
    use_ok 'Testgen::Util';
};

done_testing;

