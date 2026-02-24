<?php

return [
    'host'     => env('ELASTICSEARCH_HOST', '127.0.0.1'),
    'port'     => env('ELASTICSEARCH_PORT', 9200),
    'scheme'   => env('ELASTICSEARCH_SCHEME', 'http'),
    'username' => env('ELASTICSEARCH_USERNAME', 'elastic'),
    'password' => env('ELASTICSEARCH_PASSWORD', ''),
    'index'    => env('ELASTICSEARCH_INDEX', 'products'),
];
