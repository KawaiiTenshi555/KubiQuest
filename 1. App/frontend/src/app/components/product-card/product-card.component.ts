import { Component, Input, Output, EventEmitter } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ApiService } from '../../services/api.service';
import { Product } from '../../models/product.model';

@Component({
  selector: 'app-product-card',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './product-card.component.html',
  styleUrls: ['./product-card.component.scss'],
})
export class ProductCardComponent {
  @Input({ required: true }) product!: Product;
  @Output() productDeleted = new EventEmitter<number>();

  loading = false;

  constructor(private api: ApiService) {}

  onDelete(): void {
    if (this.loading) return;
    this.loading = true;

    this.api.deleteProduct(this.product.id).subscribe({
      next: () => {
        this.productDeleted.emit(this.product.id);
      },
      error: () => {
        this.loading = false;
      },
    });
  }

  onImageError(event: Event): void {
    (event.target as HTMLImageElement).src =
      'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2VlZSIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBkb21pbmFudC1iYXNlbGluZT0ibWlkZGxlIiB0ZXh0LWFuY2hvcj0ibWlkZGxlIiBmaWxsPSIjYWFhIiBmb250LXNpemU9IjE0Ij5ObyBpbWFnZTwvdGV4dD48L3N2Zz4=';
  }
}
