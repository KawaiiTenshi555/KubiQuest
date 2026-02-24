<?php

namespace App\Http\Controllers;

use App\Services\ElasticsearchService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class SearchController extends Controller
{
    public function __construct(private ElasticsearchService $elasticsearch) {}

    /**
     * GET /api/search?q=keyword
     * Search products in Elasticsearch.
     */
    public function index(Request $request): JsonResponse
    {
        $request->validate([
            'q' => ['required', 'string', 'min:1', 'max:255'],
        ]);

        $results = $this->elasticsearch->search($request->string('q'));

        return response()->json($results);
    }
}
