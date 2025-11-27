locals {
  # 只取当前区域前 3 个可用区，保证多 AZ 高可用
  azs = slice(data.aws_availability_zones.available.names, 0, 3)

  # 子网数量，后面需要用来创建资源
  az_count = length(local.azs)

  # 给所有资源统一的基础标签，方便后续管理和计费
  base_tags = merge({
    Environment = var.environment,
    Component   = "network",
    ManagedBy   = "terraform"
  }, var.tags)
}

# 读取区域内所有可用区，供子网分布使用
data "aws_availability_zones" "available" {
  state = "available"
}

# 创建专用 VPC，后续的公有/私有子网都放在里面
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(local.base_tags, {
    Name = "${var.name}-vpc"
  })
}

# Internet Gateway 让公有子网可以直接访问公网
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.base_tags, {
    Name = "${var.name}-igw"
  })
}

# 每个可用区一个公有子网，用于承载 NAT、堡垒机等需要公网的资源
resource "aws_subnet" "public" {
  count                   = local.az_count
  vpc_id                  = aws_vpc.this.id
  availability_zone       = local.azs[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, count.index)
  map_public_ip_on_launch = true

  tags = merge(local.base_tags, {
    Name                                        = "${var.name}-public-${local.azs[count.index]}"
    Tier                                        = "public"
    "kubernetes.io/role/elb"                    = "1" # 方便未来给 EKS 创建公有 Load Balancer
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# 每个可用区一个私有子网，内部工作负载（如 EKS 节点）运行在这里
resource "aws_subnet" "private" {
  count             = local.az_count
  vpc_id            = aws_vpc.this.id
  availability_zone = local.azs[count.index]
  # 私有子网和公有子网使用不同的网段，index + 8 可避免重叠
  cidr_block = cidrsubnet(var.vpc_cidr, 4, count.index + 8)

  tags = merge(local.base_tags, {
    Name                                        = "${var.name}-private-${local.azs[count.index]}"
    Tier                                        = "private"
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  })
}

# 弹性公网 IP 供 NAT 网关使用
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.base_tags, {
    Name = "${var.name}-nat-eip"
  })
}

# 只创建一个 NAT 网关，放在第一个公有子网里供所有私有子网共享
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = merge(local.base_tags, {
    Name = "${var.name}-nat"
  })

  depends_on = [aws_internet_gateway.this]
}

# 公有子网的路由表：直连 IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name}-public-rt"
  })
}

# 每个公有子网关联对应的路由表
resource "aws_route_table_association" "public" {
  count = local.az_count

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 私有子网的路由表：默认路由走 NAT 出去
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = merge(local.base_tags, {
    Name = "${var.name}-private-rt"
  })
}

# 每个私有子网关联私有路由表
resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
