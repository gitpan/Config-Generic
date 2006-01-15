use Module::Build;

my $build = Module::Build->new (
                                module_name => 'Config::Generic',
                                license => 'perl',
                                requires => {
                                             'perl'           => '5.8.0',
                                             'Text::Balanced'  => 0,
					     'File::Basename' => 0,
					     'Parse::RecDescent' => 0,
                                         },
                               );
$build->create_build_script;
