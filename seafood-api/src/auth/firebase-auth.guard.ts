import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';
import { FirebaseService } from '../firebase/firebase.service';

/**
 * Verifies the `Authorization: Bearer <Firebase ID token>` header and attaches
 * the caller's uid to the request. This mirrors `request.auth.uid` that Firebase
 * Callable Functions gave us for free.
 */
@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(private readonly firebase: FirebaseService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const req = context.switchToHttp().getRequest<Request & { uid?: string }>();
    const header = req.headers.authorization || '';
    const [scheme, token] = header.split(' ');

    if (scheme !== 'Bearer' || !token) {
      throw new UnauthorizedException('Missing bearer token');
    }

    try {
      const decoded = await this.firebase.verifyIdToken(token);
      req.uid = decoded.uid;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
