import { Component } from '@angular/core';
import { HealthComponent } from './components/health/health.component';
import { ProductListComponent } from './components/product-list/product-list.component';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [HealthComponent, ProductListComponent],
  templateUrl: './app.component.html',
  styleUrls: ['./app.component.scss'],
})
export class AppComponent {
  title = 'KubiQuest';
}
