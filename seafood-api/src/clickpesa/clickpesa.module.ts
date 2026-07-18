import { Module } from '@nestjs/common';
import { ClickPesaService } from './clickpesa.service';
import { PaymentsController } from './payments.controller';
import { WebhooksController } from './webhooks.controller';
import { RecommendationsModule } from '../recommendations/recommendations.module';

@Module({
  imports: [RecommendationsModule],
  controllers: [PaymentsController, WebhooksController],
  providers: [ClickPesaService],
})
export class ClickPesaModule {}
