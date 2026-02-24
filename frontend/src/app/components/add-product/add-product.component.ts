import { Component, EventEmitter, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService } from '../../services/api.service';
import { Product } from '../../models/product.model';

@Component({
  selector: 'app-add-product',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './add-product.component.html',
  styleUrls: ['./add-product.component.scss'],
})
export class AddProductComponent {
  @Output() productAdded = new EventEmitter<Product>();

  name  = '';
  image = '';
  loading = false;
  errorMsg = '';

  constructor(private api: ApiService) {}

  onSubmit(): void {
    if (!this.name.trim() || !this.image.trim()) return;

    this.loading  = true;
    this.errorMsg = '';

    this.api.createProduct(this.name.trim(), this.image.trim()).subscribe({
      next: (product) => {
        this.productAdded.emit(product);
        this.name    = '';
        this.image   = '';
        this.loading = false;
      },
      error: (err) => {
        this.errorMsg = err?.error?.message || 'Failed to create product. Please try again.';
        this.loading  = false;
      },
    });
  }
}
