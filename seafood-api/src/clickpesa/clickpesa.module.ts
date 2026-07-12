import { Module } from '@nestjs/common';
import { ClickPesaService } from './clickpesa.service';
import { PaymentsController } from './payments.controller';
import { WebhooksController } from './webhooks.controller';
import { RecommendationsService } from '../recommendations/recommendations.service';

@Module({
  controllers: [PaymentsController, WebhooksController],
  providers: [ClickPesaService, RecommendationsService],
})
export class ClickPesaModule {}
