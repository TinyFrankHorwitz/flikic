import { z } from "zod";

export const FeedItemSchema = z.object({
  game_id: z.string().min(1),
  version: z.number().int().positive(),
  title: z.string().min(1),
  creator_name: z.string().min(1),
  thumbnail_url: z.string().url(),
  manifest_url: z.string().url(),
  package_url: z.string().url(),
  package_size_bytes: z.number().int().positive(),
  sha256: z.string().regex(/^[a-f0-9]{64}$/i),
});

export const FeedResponseSchema = z.object({
  items: z.array(FeedItemSchema),
  next_cursor: z.string().nullable(),
});

export type FeedItem = z.infer<typeof FeedItemSchema>;
export type FeedResponse = z.infer<typeof FeedResponseSchema>;
