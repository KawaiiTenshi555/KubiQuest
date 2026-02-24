<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\DB;
use Prometheus\CollectorRegistry;
use Prometheus\RenderTextFormat;
use Prometheus\Storage\InMemory;

class MetricsController extends Controller
{
    public function index()
    {
        $registry = new CollectorRegistry(new InMemory());

        // --- kubiquest_products_total ---
        try {
            $count = DB::table('products')->count();
        } catch (\Throwable) {
            $count = 0;
        }

        $registry
            ->getOrRegisterGauge('kubiquest', 'products_total', 'Total number of products in MySQL')
            ->set($count);

        // --- kubiquest_mysql_up ---
        try {
            DB::connection()->getPdo();
            $mysqlUp = 1;
        } catch (\Throwable) {
            $mysqlUp = 0;
        }

        $registry
            ->getOrRegisterGauge('kubiquest', 'mysql_up', '1 if MySQL is reachable, 0 otherwise')
            ->set($mysqlUp);

        // --- kubiquest_api_info ---
        $registry
            ->getOrRegisterGauge('kubiquest', 'api_info', 'API metadata', ['version', 'pod'])
            ->set(1, ['1.0.0', gethostname()]);

        $renderer = new RenderTextFormat();
        $output   = $renderer->render($registry->getMetricFamilySamples());

        return response($output, 200, ['Content-Type' => RenderTextFormat::MIME_TYPE]);
    }
}
