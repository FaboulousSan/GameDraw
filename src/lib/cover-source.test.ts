import { describe, expect, it } from "vitest";
import { classifyCoverSource } from "./cover-source";

describe("jaquettes 1.0.4 — classification des sources", () => {
  it("gère les chemins et valeurs vides", () => {
    expect(classifyCoverSource(null).kind).toBe("empty");
    expect(classifyCoverSource("   ").kind).toBe("empty");
    expect(classifyCoverSource(" C:\\Games\\cover.png ")).toEqual({ kind: "local", value: "C:\\Games\\cover.png" });
    expect(classifyCoverSource("/home/user/image.png").kind).toBe("local");
  });
  it("différencie les URL Internet et les URI data/blob", () => {
    expect(classifyCoverSource("https://images.example/cover.jpg").kind).toBe("remote");
    expect(classifyCoverSource("http://asset.localhost/image.png").kind).toBe("remote");
    expect(classifyCoverSource("data:image/png;base64,AAAA").kind).toBe("inline");
    expect(classifyCoverSource("blob:http://127.0.0.1/1234").kind).toBe("inline");
  });
  it("rejette les protocoles inconnus et les URI script", () => {
    expect(classifyCoverSource("javascript:alert(1)").kind).toBe("invalid");
    expect(classifyCoverSource("file:///C:/secret.jpg").kind).toBe("invalid");
    expect(classifyCoverSource("ftp://example.com/file.jpg").kind).toBe("invalid");
    expect(classifyCoverSource("data:text/html;base64,AAAA").kind).toBe("invalid");
  });
});
