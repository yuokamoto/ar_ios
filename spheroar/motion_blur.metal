#include <metal_stdlib>
using namespace metal;
#include <SceneKit/scn_metal>

struct custom_node_t3 {
	float4x4 modelTransform;
	float4x4 inverseModelTransform;
	float4x4 modelViewTransform;
	float4x4 inverseModelViewTransform;
//	float4x4 normalTransform; // Inverse transpose of modelViewTransform
	float4x4 modelViewProjectionTransform;
//	float4x4 inverseModelViewProjectionTransform;
//	float2x3 boundingBox;
//	float2x3 worldBoundingBox;
};

struct custom_vertex_t
{
	float4 position [[attribute(SCNVertexSemanticPosition)]];
//	float4 color [[attribute(SCNVertexSemanticColor)]];
//	float2 texture [[attribute(SCNVertexSemanticTexcoord0)]];
};

struct out_vertex_t
{
	float4 position [[position]];
	float4 color;
	float2 uv;
};

constexpr sampler s = sampler(coord::normalized,
							  address::repeat,
							  filter::linear);

vertex out_vertex_t pass_through_vertex(custom_vertex_t in [[stage_in]],
										constant SCNSceneBuffer& scn_frame [[buffer(0)]],
										constant custom_node_t3& scn_node [[buffer(1)]]
										)
{
	out_vertex_t out;
//	out.position = in.position;
	out.position = scn_node.modelViewProjectionTransform * in.position;
	out.uv = float2((out.position.x + 1.0) * 0.5  , (out.position.y + 1.0) * -0.5);
//	out.uv = in.texture;
//	out.color = in.color;
// 	out.position = scn_frame.viewTransform * scn_node.modelTransform * scn_node.inverseModelTransform * scn_frame.inverseViewTransform * in.position;
//	out.position = scn_node.modelViewTransform * scn_node.inverseModelViewTransform * in.position;
//	out.uv = float2((out.position.x + 1.0) * 0.5  , (out.position.y + 1.0) * -0.5);
	return out;
};


fragment half4 pass_through_fragment(out_vertex_t vert [[stage_in]],
									 texture2d<float, access::sample> colorSampler [[texture(0)]]
									 )
{
	
	float4 FragmentColor = colorSampler.sample( s, vert.uv);//float4(1.0,0.0,0.0,1.0);//
	return half4( FragmentColor );
	
}

////////////////////
//gaussian blur
struct out_blur_vertex_t
{
	float4 position [[position]];
	float2 uv;
	float distance_from_camera;
};
vertex out_blur_vertex_t blur_vertex(custom_vertex_t in [[stage_in]],
									 constant SCNSceneBuffer& scn_frame [[buffer(0)]],
									 constant custom_node_t3& scn_node [[buffer(1)]]
									 )
{
	out_blur_vertex_t out;
	out.position = in.position;
	out.uv = float2((out.position.x + 1.0) * 0.5  , (out.position.y + 1.0) * -0.5);
	//	out.distance_from_camera = scn_frame.viewTransform*in.position
	return out;
};

//gausiaan weight calculation from
//http://dev.theomader.com/gaussian-kernel-calculator/
constant float weight_gb9[] = {
	0, 0.000001, 0.000014, 0.000055, 0.000088, 0.000055, 0.000014, 0.000001, 0,
	0.000001, 0.000036, 0.000362, 0.001445, 0.002289, 0.001445, 0.000362, 0.000036, 0.000001,
	0.000014, 0.000362, 0.003672, 0.014648, 0.023205, 0.014648, 0.003672, 0.000362, 0.000014,
	0.000055, 0.001445, 0.014648, 0.058434, 0.092566, 0.058434, 0.014648, 0.001445, 0.000055,
	0.000088, 0.002289, 0.023205, 0.092566, 0.146634, 0.092566, 0.023205, 0.002289, 0.000088,
	0.000055, 0.001445, 0.014648, 0.058434, 0.092566, 0.058434, 0.014648, 0.001445, 0.000055,
	0.000014, 0.000362, 0.003672, 0.014648, 0.023205, 0.014648, 0.003672, 0.000362, 0.000014,
	0.000001, 0.000036, 0.000362, 0.001445, 0.002289, 0.001445, 0.000362, 0.000036, 0.000001,
	0, 0.000001, 0.000014, 0.000055, 0.000088, 0.000055, 0.000014, 0.000001, 0
};
fragment half4 blur_flagment(out_blur_vertex_t vert [[stage_in]],
							 texture2d<float, access::sample> colorSampler [[texture(0)]],
							 texture2d<float, access::sample> headDisSampler [[texture(1)]],
							 texture2d<float, access::sample> ballDisSampler [[texture(2)]]
							 )
{
	
	float4 sum = float4(0.0);
	
	//our original texcoord for this fragment
	float2 tc = vert.uv;
	
	//the amount to blur, i.e. how far off center to sample from
	//1.0 -> blur by one pixel
	//2.0 -> blur by two pixels, etc.
	float4 head_dis = headDisSampler.sample(s, float2(tc.x, tc.y));
	float4 ball_dis = ballDisSampler.sample(s, float2(tc.x, tc.y));
	float4 distance = ball_dis;
	if( (head_dis.z < ball_dis.z && head_dis.z>0 && ball_dis.z>0) ||
	   (head_dis.z>0 && ball_dis.z==0) ){
		distance = head_dis;
	}
	float blur = fabs((distance.z*100.0-0.30)*0.01);///500.0;
	if(distance.z==0){
		blur = 0.0;
	}
	
	for (int i=-4; i<5; i++) {
		for (int j=-4; j<5; j++) {
			sum += colorSampler.sample(s, float2(tc.x + j*blur, tc.y + i*blur)) * weight_gb9[ 9*(i+4)+(j+4) ];
		}
	}
	
	//discard alpha for our simple demo, multiply by vertex color and return
	sum.a = 1.0;
//	return half4(colorSampler.sample(s, float2(tc.x, tc.y)));
	return half4(sum);//half4(distance);//half4(distance);//
}

////////////////////
//distance from camera
struct dis_vertex_t
{
	float4 position [[position]];
	float4 mv_position;
};

vertex dis_vertex_t distance_vertex(custom_vertex_t in [[stage_in]],
									constant SCNSceneBuffer& scn_frame [[buffer(0)]],
									constant custom_node_t3& scn_node [[buffer(1)]]
									)
{
	dis_vertex_t out;
	out.position = scn_node.modelViewProjectionTransform*in.position;
	out.mv_position = scn_node.modelViewTransform*in.position;
	return out;
};


fragment float4 distance_fragment(dis_vertex_t vert [[stage_in]])
{
	float z = fabs(vert.mv_position.z)*0.01;
	//	z = z;
	return float4(0.0, 0, z, 1.0);
}

////////////////////
//velocity
struct vel_vertex_t
{
	float4 position [[position]];
	float3 velocity;
//	float2 uv;
};

//struct node_uniform
//{
//	float4x4 mv;
//};

vertex vel_vertex_t velocity_vertex(custom_vertex_t in [[stage_in]],
										constant SCNSceneBuffer& scn_frame [[buffer(0)]],
										constant custom_node_t3& scn_node [[buffer(1)]],
										constant float4x4& vmvp [[buffer(2)]]
										)
{
	vel_vertex_t out;
	out.position = scn_node.modelViewProjectionTransform*in.position;
	float4 pos_pre = scn_frame.projectionTransform*scn_frame.viewTransform* vmvp*in.position;
	out.velocity = ( out.position - pos_pre).xyz;
//	out.velocity = in.position.xyz;
//	out.position = pos_pre;
	return out;
};


fragment float4 velocity_fragment(vel_vertex_t vert [[stage_in]])
{
//	float4 FragmentColor = colorSampler.sample( s, vert.uv);//float4(1.0,0.0,0.0,1.0);//
//	float4 vel = float4(0.0, 1.0, 0.0, 1.0);
//	return vel;
	return float4(vert.velocity.x, vert.velocity.y, vert.velocity.z, 1.0);
}

//////////////////////////////
//motion blur

vertex out_vertex_t motion_blur_vertex(custom_vertex_t in [[stage_in]],
										constant SCNSceneBuffer& scn_frame [[buffer(0)]]
										)
{
	out_vertex_t out;
	out.position = in.position;
	out.uv = float2((out.position.x + 1.0) * 0.5  , (out.position.y + 1.0) * -0.5);
	return out;
};


// v 方向の n 画素の色の平均を求める
float4 average(float2 uv, float2 v, int n, float exp_rate, float exp_delay,
			   texture2d<float, access::sample> colorSampler
			   )
{
	float4 c = float4(0.0);

	for (int i = 0; i < n; ++i)
	{
		c += colorSampler.sample(s, uv + v * (float(i) / float(n) * exp_rate - exp_delay));
	}

	return c / float(n);
}
fragment half4 motion_blur_fragment(out_vertex_t vert [[stage_in]],
									 texture2d<float, access::sample> colorSampler [[texture(0)]],
									 texture2d<float, access::sample> headVelSampler [[texture(1)]],
									 texture2d<float, access::sample> ballVelSampler [[texture(2)]]
									)
{
	
//	float4 FragmentColor = colorSampler.sample( s, vert.uv);//float4(1.0,0.0,0.0,1.0);//
//	float4 v = velocitySampler.sample( s, vert.uv);
//	return half4(1.0,0.0,0.0,1.0);//
//	return half4( FragmentColor );
//	return half4( velocity );
	
	float exp_rate = 2.0;// 露光時間比
	float exp_delay = 1.0;// 露光遅延
	int samples = 16;// サンプル数
	
	float4 out;
	// 速度バッファから速度を取り出す
	float4 v_ball = ballVelSampler.sample( s, vert.uv);//*50.0;
	float4 v_head = headVelSampler.sample( s, vert.uv);//*1.0;
	if (v_head.x != 0.0 || v_head.y != 0.0)
	{
		// フラグメントがオブジェクト上ならそこをぼかす
		out = average(vert.uv, v_head.xy, samples, exp_rate, exp_delay, colorSampler);
	}
	else if(v_ball.x != 0.0 || v_ball.y != 0.0)
	{
		// フラグメントがオブジェクト上ならそこをぼかす
		out = average(vert.uv, v_ball.xy, samples, exp_rate, exp_delay, colorSampler);
//		out = float4(1.0,0.0,0.0,1.0);
//		float4 c = float4(0.0);
//		for (int i = 0; i < samples; ++i)
//		{
//			c += colorSampler.sample(s, vert.uv + v.xy * (float(i) / float(samples) * exp_rate - exp_delay));
//		}
//		out = c / float(samples);
	}
	else
	{
		out =  colorSampler.sample( s, vert.uv);
//		// フラグメントがオブジェクトの外部なら
//		int count = 0;
//		vec4 d = vec4(0.0);
//
//		for (int i = 0; i < 16; ++i)
//		{
//			// そのフラグメントの周囲をランダムにサンプリングして
//			vec4 p = get_vel(vel, vel_dir, uv + rnc*rand(uv));
//
//			if (p.a != 0.0)
//			{
//				// オブジェクト上のフラグメントが見つかったら
//				vec4 q = get_vel(vel, vel_dir, uv+ p.xy);
//
//				if (q.a != 0.0)
//				{
//					// その先のフラグメントがオブジェクト上ならそこをぼかす
//					d += average(q.xy, samples);
//					++count;
//				}
//				d += average(p.xy, samples);
//				++count;
//			}
//		}
//
//		if (count == 0)
//			gl_FragColor = texture2D(colorSampler, uv);
//		else
//			gl_FragColor = d / float(count);
	}
//	out = v_head*10.0;
//	out =  colorSampler.sample( s, vert.uv);

	return half4(out);
}
