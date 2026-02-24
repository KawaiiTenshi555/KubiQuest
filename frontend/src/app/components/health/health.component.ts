import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Subscription, interval, startWith, switchMap, catchError, of } from 'rxjs';
import { ApiService } from '../../services/api.service';
import { Health } from '../../models/health.model';

@Component({
  selector: 'app-health',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './health.component.html',
  styleUrls: ['./health.component.scss'],
})
export class HealthComponent implements OnInit, OnDestroy {
  health: Health | null = null;
  error = false;
  private sub?: Subscription;

  constructor(private api: ApiService) {}

  ngOnInit(): void {
    // Poll every 30 seconds
    this.sub = interval(30_000)
      .pipe(
        startWith(0),
        switchMap(() =>
          this.api.getHealth().pipe(
            catchError(() => {
              this.error = true;
              return of(null);
            })
          )
        )
      )
      .subscribe((h) => {
        if (h) {
          this.health = h;
          this.error = false;
        }
      });
  }

  ngOnDestroy(): void {
    this.sub?.unsubscribe();
  }
}
