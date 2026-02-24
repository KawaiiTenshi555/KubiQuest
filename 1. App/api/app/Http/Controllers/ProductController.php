<?php

namespace App\Http\Controllers;

use App\Models\Product;
use App\Services\RabbitMQService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ProductController extends Controller
{
    public function __construct(private RabbitMQService $rabbitmq) {}

    /**
     * GET /api/products
     * List all products from MySQL.
     */
    public function index(): JsonResponse
    {
        $products = Product::latest()->get(['id', 'name', 'image', 'created_at']);

        return response()->json($products);
    }

    /**
     * POST /api/products
     * Create a product in MySQL and publish to RabbitMQ.
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name'  => ['required', 'string', 'max:255'],
            'image' => ['required', 'string', 'max:512'],
        ]);

        $product = Product::create($validated);

        $this->rabbitmq->publish('created', [
            'id'    => $product->id,
            'name'  => $product->name,
            'image' => $product->image,
        ]);

        return response()->json($product, 201);
    }

    /**
     * DELETE /api/products/{id}
     * Delete a product from MySQL and publish to RabbitMQ.
     */
    public function destroy(int $id): JsonResponse
    {
        $product = Product::findOrFail($id);

        $payload = [
            'id'    => $product->id,
            'name'  => $product->name,
            'image' => $product->image,
        ];

        $product->delete();

        $this->rabbitmq->publish('deleted', $payload);

        return response()->json(null, 204);
    }
}
