<?php

namespace App\Http\Controllers;

use App\Services\ElasticsearchService;
use App\Services\RabbitMQService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class HealthController extends Controller
{
    public function __construct(
        private ElasticsearchService $elasticsearch,
        private RabbitMQService      $rabbitmq,
    ) {}

    public function index(): JsonResponse
    {
        $start = microtime(true);

        // MySQL health + product count
        $mysqlStatus     = 'error';
        $productCount    = 0;
        $migrationsStatus = 'error';

        try {
            $productCount     = DB::table('products')->count();
            $mysqlStatus      = 'healthy';
            $migrationsStatus = Schema::hasTable('migrations') ? 'healthy' : 'error';
        } catch (\Exception) {
            // statuses stay 'error'
        }

        // Elasticsearch health
        $esStatus = $this->elasticsearch->ping() ? 'healthy' : 'error';

        // RabbitMQ pending messages
        $msgs = $this->rabbitmq->getQueueMessageCount();

        $responseTimeMs = (int) round((microtime(true) - $start) * 1000);

        return response()->json([
            'hostname'         => gethostname(),
            'mysql'            => $mysqlStatus,
            'products'         => $productCount,
            'mysql_migrations' => $migrationsStatus,
            'elasticsearch'    => $esStatus,
            'msgs'             => $msgs,
            'response_time_ms' => $responseTimeMs,
        ]);
    }
}
