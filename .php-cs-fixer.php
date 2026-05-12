<?php

$finder = PhpCsFixer\Finder::create()
    ->in(__DIR__)
    ->exclude('vendor')
    ->exclude('externals')
    ->exclude('webtrees')
    ->exclude('webtrees-upstream')
    ->exclude('util/includes/pear')
    ->exclude('util/includes/getid3')
    ->exclude('util/includes/simplepie')
    ->exclude('util/includes/jpeg_metadata_tk')
    ->exclude('util/includes/datasets')
    ->exclude('util/includes/htmlpurifier-4.15.0')
    ->exclude('util/includes/phpmailer')
    ->exclude('util/includes/phpsniff')
    ->exclude('util/includes/phpcoord')
    ->exclude('util/includes/htmlparser')
    ->exclude('util/includes/htmlpure')
    ->exclude('util/includes/spyc')
    ->exclude('util/includes/dBug')
    ->exclude('util/includes/cufon')
    ->exclude('utils/pear');

return (new PhpCsFixer\Config())
    ->setRiskyAllowed(true)
    ->setRules([
        // Already applied
        'array_syntax' => ['syntax' => 'short'],

        // Code style & formatting
        'single_quote'                    => true,
        'trailing_comma_in_multiline'     => ['elements' => ['arrays', 'arguments', 'parameters']],
        'no_trailing_whitespace'          => true,
        'no_extra_blank_lines'            => ['tokens' => ['extra', 'throw', 'use']],
        'ordered_imports'                 => ['sort_algorithm' => 'alpha'],
        'blank_line_after_namespace'      => true,
        'no_whitespace_in_blank_line'     => true,

        // PHP 8.x modernisation
        'modernize_types_casting'         => true,  // intval() → (int) etc.  [risky]
        'get_class_to_class_keyword'      => true,  // get_class($x) → $x::class
        'ternary_to_null_coalescing'      => true,  // isset($x) ? $x : $y → $x ?? $y
        'use_arrow_functions'             => true,  // eligible closures → fn() =>  [risky]

        // Dead code cleanup
        'no_unused_imports'               => true,
        'no_useless_else'                 => true,
        'no_useless_return'               => true,
    ])
    ->setFinder($finder);
