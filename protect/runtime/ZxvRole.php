<?php

namespace Pterodactyl\Support;

use Illuminate\Support\Facades\DB;
use Pterodactyl\Models\User;

final class ZxvRole
{
    public const USER = 'user';
    public const ADP = 'adp';
    public const OWNER = 'owner';
    public const CEO = 'ceo';

    public static function current(?User $user = null): string
    {
        $user ??= auth()->user();
        if (!$user) return self::USER;
        if ((int) $user->id === 1) return self::CEO;
        try {
            return (string) (DB::table('zxv_roles')->where('user_id', $user->id)->value('role') ?: self::USER);
        } catch (\Throwable) {
            return self::USER;
        }
    }

    public static function is(string|array $roles, ?User $user = null): bool
    {
        $roles = (array) $roles;
        return in_array(self::current($user), $roles, true);
    }

    public static function label(string $role): string
    {
        return match ($role) {
            self::CEO => 'CEO',
            self::OWNER => 'OWNER',
            self::ADP => 'ADP',
            default => 'USER',
        };
    }

    public static function canCreateServer(?User $user = null): bool
    {
        return self::is([self::ADP, self::OWNER, self::CEO], $user);
    }

    public static function canOpenDashboard(?User $user = null): bool
    {
        return self::is([self::OWNER, self::CEO], $user);
    }

    public static function canReadAdminPanel(?User $user = null): bool
    {
        return self::is([self::ADP, self::OWNER, self::CEO], $user);
    }

    public static function canCreateAdminUser(?User $user = null): bool
    {
        return self::is(self::CEO, $user);
    }

    public static function canAssign(string $targetRole, ?User $user = null): bool
    {
        $role = self::current($user);
        if ($role === self::CEO) {
            return in_array($targetRole, [self::USER, self::ADP, self::OWNER], true);
        }
        if ($role === self::OWNER) {
            return in_array($targetRole, [self::USER, self::ADP], true);
        }
        return $targetRole === self::USER && false;
    }

    public static function canTouchUser(User $target, ?User $actor = null): bool
    {
        $actorRole = self::current($actor);
        if ($actorRole === self::CEO) return (int) $target->id !== 1;
        if ($actorRole === self::OWNER) return self::current($target) !== self::CEO && (int) $target->id !== 1;
        return false;
    }
}
