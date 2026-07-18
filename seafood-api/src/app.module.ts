import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { FirebaseModule } from './firebase/firebase.module';
import { ClickPesaModule } from './clickpesa/clickpesa.module';
import { NotificationsModule } from './notifications/notifications.module';
import { RecommendationsModule } from './recommendations/recommendations.module';
import { PagesController } from './pages/pages.controller';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    FirebaseModule,
    ClickPesaModule,
    NotificationsModule,
    RecommendationsModule,
  ],
  controllers: [PagesController],
})
export class AppModule {}
