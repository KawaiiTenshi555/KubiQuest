<?php

namespace App\Services;

use PhpAmqpLib\Connection\AMQPStreamConnection;
use PhpAmqpLib\Message\AMQPMessage;
use Illuminate\Support\Facades\Log;

class RabbitMQService
{
    private string $host;
    private int    $port;
    private string $user;
    private string $password;
    private string $vhost;
    private string $exchange;

    public function __construct()
    {
        $this->host     = config('rabbitmq.host');
        $this->port     = config('rabbitmq.port');
        $this->user     = config('rabbitmq.user');
        $this->password = config('rabbitmq.password');
        $this->vhost    = config('rabbitmq.vhost');
        $this->exchange = config('rabbitmq.exchange');
    }

    /**
     * Publish a product event to the RabbitMQ fanout exchange.
     */
    public function publish(string $action, array $product): void
    {
        $connection = null;
        $channel    = null;

        try {
            $connection = new AMQPStreamConnection(
                $this->host,
                $this->port,
                $this->user,
                $this->password,
                $this->vhost
            );

            $channel = $connection->channel();

            // Declare fanout exchange (idempotent)
            $channel->exchange_declare(
                exchange: $this->exchange,
                type: 'fanout',
                passive: false,
                durable: true,
                auto_delete: false
            );

            $body = json_encode([
                'action'  => $action,
                'product' => $product,
            ]);

            $message = new AMQPMessage($body, [
                'content_type'  => 'application/json',
                'delivery_mode' => AMQPMessage::DELIVERY_MODE_PERSISTENT,
            ]);

            $channel->basic_publish($message, $this->exchange);

            Log::info("RabbitMQ: published [{$action}] for product #{$product['id']}");
        } catch (\Exception $e) {
            // Non-blocking: log the error but don't fail the HTTP request
            Log::error("RabbitMQ publish failed: " . $e->getMessage());
        } finally {
            $channel?->close();
            $connection?->close();
        }
    }

    /**
     * Count messages in the indexer queue via the management API.
     * Returns -1 if unavailable.
     */
    public function getQueueMessageCount(): int
    {
        try {
            $url  = "http://{$this->host}:15672/api/queues/" . urlencode($this->vhost) . "/products-indexer";
            $ctx  = stream_context_create([
                'http' => [
                    'timeout' => 2,
                    'header'  => 'Authorization: Basic ' . base64_encode("{$this->user}:{$this->password}"),
                ],
            ]);
            $json = @file_get_contents($url, false, $ctx);
            if ($json === false) {
                return -1;
            }
            $data = json_decode($json, true);
            return $data['messages'] ?? 0;
        } catch (\Exception) {
            return -1;
        }
    }
}
