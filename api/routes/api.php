<?php

use App\Http\Controllers\HealthController;
use App\Http\Controllers\MetricsController;
use App\Http\Controllers\ProductController;
use App\Http\Controllers\SearchController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| KubiQuest API Routes
|--------------------------------------------------------------------------
*/

Route::get('/health', [HealthController::class, 'index']);
Route::get('/metrics', [MetricsController::class, 'index']);

Route::apiResource('/products', ProductController::class)
    ->only(['index', 'store', 'destroy']);

Route::get('/search', [SearchController::class, 'index']);
