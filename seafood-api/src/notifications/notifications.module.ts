import { Module } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { OrderListenerService } from './order-listener.service';

@Module({
  providers: [NotificationsService, OrderListenerService],
})
export class NotificationsModule {}
