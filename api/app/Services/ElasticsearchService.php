<?php

namespace App\Services;

use Elastic\Elasticsearch\ClientBuilder;
use Elastic\Elasticsearch\Client;
use Illuminate\Support\Facades\Log;

class ElasticsearchService
{
    private Client $client;
    private string $index;

    public function __construct()
    {
        $host     = config('elasticsearch.host');
        $port     = config('elasticsearch.port');
        $scheme   = config('elasticsearch.scheme');
        $username = config('elasticsearch.username');
        $password = config('elasticsearch.password');
        $this->index = config('elasticsearch.index');

        $builder = ClientBuilder::create()
            ->setHosts(["{$scheme}://{$host}:{$port}"]);

        if ($username && $password) {
            $builder->setBasicAuthentication($username, $password);
        }

        $this->client = $builder->build();
    }

    /**
     * Ping Elasticsearch. Returns true if reachable.
     */
    public function ping(): bool
    {
        try {
            return $this->client->ping()->asBool();
        } catch (\Exception) {
            return false;
        }
    }

    /**
     * Full-text search in the products index.
     *
     * @return array<int, array{id: int, name: string, image: string}>
     */
    public function search(string $query): array
    {
        try {
            $response = $this->client->search([
                'index' => $this->index,
                'body'  => [
                    'query' => [
                        'match' => [
                            'name' => [
                                'query'     => $query,
                                'fuzziness' => 'AUTO',
                            ],
                        ],
                    ],
                    'size' => 100,
                ],
            ]);

            $hits = $response->asArray()['hits']['hits'] ?? [];

            return array_map(fn($hit) => $hit['_source'], $hits);
        } catch (\Exception $e) {
            Log::error("Elasticsearch search failed: " . $e->getMessage());
            return [];
        }
    }
}
