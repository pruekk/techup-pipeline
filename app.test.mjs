import request from "supertest";
import app from "./app.mjs";

describe("GET /", () => {
    it("should return array of queries with their values", async () => {
        const res = await request(app).get("/?user=admin&role=editor");
        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty("data");
        expect(Array.isArray(res.body.data)).toBe(true);
        expect(res.body.data).toEqual(
            expect.arrayContaining([
                { query: "user", value: "admin" },
                { query: "role", value: "editor" },
            ])
        );
    });

    it("should return empty array when no query params", async () => {
        const res = await request(app).get("/");
        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty("data");
        expect(Array.isArray(res.body.data)).toBe(true);
        expect(res.body.data.length).toBe(0);
    });

    it("should support array values for repeated query params", async () => {
        const res = await request(app).get("/?tag=a&tag=b");
        expect(res.statusCode).toBe(200);
        expect(res.body.data).toEqual(
            expect.arrayContaining([{ query: "tag", value: ["a", "b"] }])
        );
    });
});

describe("GET /posts", () => {
    it("should return list of posts with pagination info", async () => {
        const res = await request(app).get("/posts");
        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty("posts");
        expect(res.body).toHaveProperty("totalPosts");
    });
});

describe("GET /posts/:id", () => {
    it("should return a post if it exists", async () => {
        const res = await request(app).get("/posts/1");
        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty("id", 1);
    });

    it("should return 404 if post does not exist", async () => {
        const res = await request(app).get("/posts/99999");
        expect(res.statusCode).toBe(404);
        expect(res.body).toHaveProperty("error", "Blog post not found");
    });
});
