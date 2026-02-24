import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import {
  Subject,
  Subscription,
  debounceTime,
  distinctUntilChanged,
  switchMap,
  catchError,
  of,
} from 'rxjs';
import { ApiService } from '../../services/api.service';
import { Product } from '../../models/product.model';
import { ProductCardComponent } from '../product-card/product-card.component';
import { AddProductComponent } from '../add-product/add-product.component';

@Component({
  selector: 'app-product-list',
  standalone: true,
  imports: [CommonModule, FormsModule, ProductCardComponent, AddProductComponent],
  templateUrl: './product-list.component.html',
  styleUrls: ['./product-list.component.scss'],
})
export class ProductListComponent implements OnInit, OnDestroy {
  products: Product[] = [];
  loading = false;

  searchQuery  = '';
  private search$ = new Subject<string>();
  private subs: Subscription[] = [];

  constructor(private api: ApiService) {}

  ngOnInit(): void {
    this.loadProducts();

    // Debounced search
    const searchSub = this.search$
      .pipe(
        debounceTime(300),
        distinctUntilChanged(),
        switchMap((q) => {
          this.loading = true;
          if (!q.trim()) {
            return this.api.getProducts().pipe(catchError(() => of([])));
          }
          return this.api.searchProducts(q).pipe(catchError(() => of([])));
        })
      )
      .subscribe((products) => {
        this.products = products;
        this.loading  = false;
      });

    this.subs.push(searchSub);
  }

  ngOnDestroy(): void {
    this.subs.forEach((s) => s.unsubscribe());
  }

  loadProducts(): void {
    this.loading = true;
    this.api.getProducts().subscribe({
      next:  (p) => { this.products = p; this.loading = false; },
      error: ()  => { this.loading = false; },
    });
  }

  onSearchChange(): void {
    this.search$.next(this.searchQuery);
  }

  onProductAdded(product: Product): void {
    this.products = [product, ...this.products];
  }

  onProductDeleted(id: number): void {
    this.products = this.products.filter((p) => p.id !== id);
  }

  trackById(_: number, p: Product): number {
    return p.id;
  }
}
