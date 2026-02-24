export interface Health {
  hostname: string;
  mysql: 'healthy' | 'error';
  products: number;
  mysql_migrations: 'healthy' | 'error';
  elasticsearch: 'healthy' | 'error';
  msgs: number;
  response_time_ms: number;
}
